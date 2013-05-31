module XmlActiveRecordBase
=begin
  There are 4 conventions in place for using this library

  CONVENTIONS:
  api_attr_accessor - Array - This mode extends the standard attr_accessor
    and keeps track of the attributes for the subclass so they are accessible for meta programming
  api_has_many - Array - This mode also extends the standard attr_accessor
    and keeps track of collections that are represented in nested XML collections of items modeled
    by an associated ruby model. Naming conventions are underscore and singular. The expectation is the
    XML collection will be a plural camelcase variant.
  api_belongs_to - Array - This mode also extends the standard attr_accessor
    and keeps track of parent relationships to a ruby model. Belongs is only useful in cases where the entity
    is a collection element.
  api_assume_parent - Array - This mode allows a model to recursively assume itself as a parent in the event of
    odd xml constructions. The item will be matched as a collection and then returned as the named assessor for the
    group. Syntax for this is underscore plural of the XML collection

  UTILITY:
  api_attr_accessor_alias - Hash - Allows for failures in the naming convention of the API or a desired renaming of internal
    DSL to match to the XML. Aliases do not apply to has_many relationships at this time but will. Aliases follow the same
    naming conventions as standard api_attr_accessor's in that they are singular and underscored
=end

	class APIModelBase
		require 'rexml/document'
		include REXML

		include XmlActiveRecordCallback

	  def initialize *hash
	    hash = hash.first
	    @make_assumptions = true
	    @sanitized = false
	    unless hash.blank?
	      @make_assumptions = hash[:make_assumptions] unless hash[:make_assumptions].nil?
	      @sanitized = hash[:sanitized] unless hash[:sanitized].nil?
	    end
	    self.instance_variable_set :@assumed_parent, self.class.assumed_parent.dup
	    self.instance_variable_get(:@assumed_parent).clear unless @make_assumptions
	    self.instance_variable_set :@collections, self.class.collections.dup
	    self.instance_variable_set :@attributes, self.class.attributes.dup
	    self.instance_variable_set :@aliases, self.class.aliases.dup
	    self.instance_variable_set :@belongs, self.class.belongs.dup
	    self.instance_variable_set :@cacheable, self.class.cacheable.dup
	    cacheable = self.instance_variable_get :@cacheable
	  end

		def self.api_attr_accessor(*names)
			names.map{|name| attr_accessor name}
			self.group_inits
	    @attributes.concat names
		end

	  def self.api_xml_attributes(hashes)
	    self.group_inits
	    @xml_attributes.merge! hashes
	  end

		def self.api_has_many(*names)
			names.map{|name| attr_accessor name}
			self.group_inits
	    @collections.concat names
		end

	  def self.api_attr_accessor_alias(hashes)
	    self.group_inits
	    @aliases.merge! hashes
	  end

	  def self.api_belongs_to(*names)
	    names.map{|name| attr_accessor name}
	    self.group_inits
	    @belongs.concat names
	  end

	  def self.api_assume_parent(*names)
	    names.map{|name| attr_accessor name}
	    self.group_inits
	    @assumed_parent.concat names
	  end

		def self.group_inits
			@collections ||= []
			@attributes ||= []
			@aliases ||= {}
			@xml_attributes ||= {}
			@belongs ||= []
			@assumed_parent ||= []
			@cacheable ||= []
		end

		def text_from_element(xmldoc, attrib)
			xmldoc.root.elements[attrib.to_s.camelcase].text
		end

	  def sanitize_xml(xmldoc, *things)
	    xmlstr = xmldoc.to_s
	    things.each do |thing|
	      xmlstr.gsub! thing, ""
	    end
	    Document.new xmlstr
	  end

		def enum_from_element(xmldoc, attrib)
			xmldoc.root.elements[attrib.to_s.camelcase].to_enum
		end

	  def self.collections
	  	@collections
	  end

	  def collections
	  	self.class.collections
	  end

	  def aliases
	    self.class.aliases
	  end

	  def self.aliases
	    @aliases
	  end

	  def assumed_parent
	    self.class.assumed_parent
	  end

	  def self.assumed_parent
	    @assumed_parent
	  end

	  def self.attributes
	    @attributes
	  end

	  def attributes
	  	self.class.attributes
	  end

	  def xml_attributes
	    self.class.xml_attributes
	  end

	  def self.xml_attributes
	    @xml_attributes
	  end

	  def belongs
	    self.class.belongs
	  end

	  def self.belongs
	    @belongs
	  end

	  def cacheable
  		self.class.cacheable
		end

		def self.cacheable
			@cacheable
		end

		def self.get_document_from_string(string)
			Document.new(string)
		end

	  def process_attributes xmldoc
	    @attributes.each do |attrib|
	      begin
	        self.send "#{attrib}=", text_from_element(xmldoc, attrib)
	      rescue
	        api_al = self.aliases[attrib]
	        Rails.logger.debug "Stupid FD Naming convetions are for kids #{api_al} #{attrib}"
	        begin
	          Rails.logger.debug "Checking for Alias"
	          self.send "#{attrib}=", text_from_element(xmldoc, api_al) unless api_al.nil?
	        rescue
	          Rails.logger.debug "Stupid You your alias doesn't match either"
	        end
	      end
	    end
	  end

	  def process_collections xmldoc
	    @collections.each do |col|
	      enum = enum_from_element(xmldoc, col)
	      collect ||= []
	      enum.each do |elem|
	        sub_doc = Document.new elem.to_s # Creates a new subdocument representing the nested xml body for the collection
	        unless sub_doc.document.nil?
	          Rails.logger.debug "Processing Children"
	          #Adds the Collection to the parents attribute that was named with api_has_many for each item
	          clazz = Object.const_get("#{col.to_s.singularize.camelcase}")
	          class_element = clazz.new sanitized: true
	          class_element.belongs.each do |belong|
	            #Refactor to assign correct belongs in the event of multiple belongs to.
	            if belong.to_s.camelcase == self.class.to_s
	              class_element.send "#{belong}=", self
	            end
	            #needs to be validated
	          end
	          collect.push(class_element.send "initialize_with_xml", sub_doc)
	        end
	      end
	      self.send "#{col}=", collect
	    end
	  end
		
	  def process_assumptions xmldoc
	    Rails.logger.debug "Self Assuming"
	    @assumed_parent.each do |col|
	      enum = [].to_enum
	      collect ||= {}
	      enum = xmldoc.root.elements[col.to_s.singularize.camelcase].parent.each
	      enum.each do |elem|
	        unless elem.to_s.gsub(" ","").empty?
	          Rails.logger.debug "#{elem.attributes[xml_attributes[col].to_s.camelcase]} New Category Detected"
	          subcollect = collect[elem.attributes[xml_attributes[col].to_s.camelcase]] ||= []
	          sub_doc = Document.new elem.to_s
	          unless sub_doc.document.nil?
	            Rails.logger.debug "Proccessing Assumed Children"
	            #enum_from_element(sub_doc, self.class.to_s).each do |item|
	            sub_doc.root.elements.each do |item|
	              sub_sub_doc = Document.new item.to_s
	              clazz = Object.const_get(self.class.to_s)
	              class_element = clazz.new make_assumptions: false, sanitized: true
	              subcollect.push(class_element.send "initialize_with_xml",sub_sub_doc)unless sub_sub_doc.document.nil?
	            end
	          end
	          self.send "#{col}=", collect
	        end
	      end
	    end
	  end

		def initialize_with_xml(xmldoc) #WARNING Lots of Nasty self evoked recursions is possible here 
	    start = Time.now
	    if xmldoc.root.name == "Error" #Responds to the console if an error is captured.
	      Rails.logger.info "Error Code #{xmldoc.root.elements['Code'].text}"
	      return nil
	    end

	    xmldoc = sanitize_xml(xmldoc, "\n") unless @sanitized

	    process_attributes xmldoc

	    process_collections xmldoc

	    Rails.logger.debug "Ignoring? #{@ignore_assumptions}"
	    process_assumptions xmldoc
	    
	    stop = Time.now
	    Rails.logger.info "DONE! Finished in #{stop - start}"
	    self
	  end

	  def initialize_with_string(string)
	    #Construct with XML
	    raise "Cannot Call from Base Class"
	  end

	  def initialize_with_hash(hash)
	    #Construct with Hash
	    raise "Cannot Call from Base Class"
	  end

	  def initialize_with_object(obj)
	    #Construct with Object Deep Copy
	    raise "Cannot Call from Base Class"
	  end

	end
end