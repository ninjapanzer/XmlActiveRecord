=begin
  Although not aptly named this library mobdule for XMLActiveRecordBase adds a request caching layer on the method level
  Rails is expected. If running stand along please set Rails.root to you tmp path.

  CONVENTIONS:
  api_set_cacheable - Array - This method which must be used after a method is in scope so below the definition
  	eg. def self.find_all
					response = HTTParty.get("Some Path that returns XML")
					self.new.initialize_with_xml(get_document_from_string response.body)
				end

				api_use_cache :find_all
		The result of the method call will be marshalled and stored in a global hash for 30 minutes - Configuration to be added later.
		Any subsequent requests to that call will be retrieved from cache.
		The use case for this cache is when creating large collections from XML of a remote system. The request and creation time is often much longer than is
		desirable when the data is unlikely to change. 
=end

module XmlActiveRecordCallback
	class Proc
	  	def callback(callable, *args)
	    	self === Class.new do
		      method_name = callable.to_sym
		      define_method(method_name) { |&block| block.nil? ? true : block.call(*args) }
		      define_method("#{method_name}?") { true }
		      def method_missing(method_name, *args, &block) false; end
	    	end.new
	  	end
		end

		def self.included(base)
  		class << base

  			def self.setup_cache_index
					FileUtils.rm_r "#{Rails.root}/tmp/cache/api_requests"
					FileUtils.mkdir "#{Rails.root}/tmp/cache/api_requests"
				end

		  	def api_set_cacheable(*names)
			  	self.group_inits
					@cacheable ||= []
					@cacheable.concat names
				end

				def setup_cache_index
					FileUtils.rm_r "#{Rails.root}/tmp/cache/api_requests"
					FileUtils.mkdir "#{Rails.root}/tmp/cache/api_requests"
				end

				setup_cache_index #do some first time run setup

				def set_cache object, meth, argstr
					$cache ||= {}
					file = Tempfile.open "#{self}_#{meth}_CacheFile_", "#{Rails.root}/tmp/cache/api_requests" do |os|
						Marshal.dump object, os
					end
					File.open "#{Rails.root}/tmp/cache/api_requests/.cache_index", 'a+' do |index|
						index.write file.path
						index.write "\n"
					end
					$cache["#{self}##{meth}##{argstr}"] = [Time.now.to_i, file]
				end

				def get_cache meth, argstr #method name and argument string
					$cache ||= {}
					cache_name = "#{self}##{meth}##{argstr}"
					cache_node = $cache[cache_name]
					unless cache_node.blank?
						if (cache_node.first > (Time.now + 30.minutes).to_i)
							cache_node.last.unlink
							$cache.delete cache_name
							return nil
						else
							if File.exists? cache_node.last.path
								return Marshal.load(File.read(cache_node.last))
							else
								$cache.delete cache_name
							end
							return nil
						end
					end
				end

				def api_use_cache(meth)
				  Rails.logger.debug "before filter called"
				  api_set_cacheable meth
				  singleton_class.send 'define_method', "#{meth}_without_cache" do |*args|
				  	Rails.logger.debug 'Just Going For It'
				  end
				  singleton_class.send 'define_method', "#{meth}_with_cache" do |*args|
				  	Rails.logger.debug 'checking cache'
				  	cache_node = get_cache meth, args.join
				  	return cache_node unless cache_node.blank?
				  	Rails.logger.debug 'going to call former method'
				    live_node = self.send "#{meth}_without_cache", *args
				    set_cache live_node, meth, args.join
				    live_node
				  end
				  singleton_class.send "alias_method_chain", meth, :cache
				end
			end
		end

end