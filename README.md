WHY
===

Well our client has an XML only API and I figured it would be nice to construct objects that we can interact with in opposition to building hashes from the returned media. And as a blinding opportunity to learn ruby meta programming. I took to building this for a purpose library. While I am not sure it is very modular to other projects at this moment I hope it may help others understand some of the processes for building ruby meta code. I know it helped me.

History
=======

The idea here is simple enough but ruby meta programming is a bit tricky. First of all Classes have made overlapping scopes from the singleton to the instance. Identifying what scope an operation is occuring in is a bit of a challenge. On top of that learning how to include mixins is something of a struggle. Especially when you are blind hacking at it. My first iteration of this process was jammed full of bar = eval ":#{foo}" statements. After some pairing I was educated on the slowness of eval and moved on to more method based introspections like send and Object.get_const to help me on my way. Once I had successfully factored those monsters out I continued to add features which led to my exploration fo callbacks.

The callback in this case if for method level caching. The response of each method is Marshalled to a Tempfile for quick retrieval later. In many cases I was caching the recursive expansion of objects from XML. This takes too much time to process when the data is coming from a remote system. Request run in normal time once cached and while there is not an external configuration for the cache it is easy to change the callbacks to refresh longer or shorter than 30 minutes. Just ask me how.

XmlActiveRecord
===============

Can take XML and turn it into objects with ActiveRecord Style Macros

  There are 4 conventions in place for using this library

  CONVENTIONS:
  
  **api_attr_accessor** - Array - This mode extends the standard attr_accessor and keeps track of the attributes for the subclass so they are accessible for meta programming
  
  **api_has_many** - Array - This mode also extends the standard attr_accessor and keeps track of collections that are represented in nested XML collections of items modeled by an associated ruby model. Naming conventions are underscore and singular. The expectation is the XML collection will be a plural camelcase variant.
  
  **api_belongs_to** - Array - This mode also extends the standard attr_accessor and keeps track of parent relationships to a ruby model. Belongs is only useful in cases where the entity is a collection element.
  
  **api_assume_parent** - Array - This mode allows a model to recursively assume itself as a parent in the event of odd xml constructions. The item will be matched as a collection and then returned as the named assessor for the group. Syntax for this is underscore plural of the XML collection
    

    eg. class FilterAttributes < XmlActiveRecordBase::APIModelBase
  	        api_assume_parent :attributes
		    api_xml_attributes attributes: :caption
		    api_attr_accessor :id, :result_count, :name

		    def self.find_by_id link_id
		        response = HTTParty.get("Some path that returns XML")
			    self.new.initialize_with_xml(get_document_from_string response.body)
			end

			api_use_cache :find_by_id
		end


  UTILITY:
  
  **api_attr_accessor_alias** - Hash - Allows for failures in the naming convention of the API or a desired renaming of internal DSL to match to the XML. Aliases do not apply to has_many relationships at this time but will. Aliases follow the same naming conventions as standard api_attr_accessor's in that they are singular and underscored.
  
  **api_xml_attributes** - Hash - This allows for api_assume_parent to be configured. - This is already on the chopping block to be integrated into the configuration of api_assume_parent since it is required.
  
  **sanitize_xml**(xmldoc, *things) - xmldoc, Array of strings - During testing it was found that some XML contains formatting characters which are rendered as undefined xml element nodes. To remove them before processing run this inside your processing method first.

XmlActiveRecordCallback
=======================

Although not aptly named this library mobdule for XMLActiveRecordBase adds a request caching layer on the method level Rails is expected. If running stand along please set Rails.root to you tmp path.

  CONVENTIONS:
  
  **api_set_cacheable** - Array - This method which must be used after a method is in scope so below the definition
  
    eg. def self.find_all
	        response = HTTParty.get("Some Path that returns XML")
		    self.new.initialize_with_xml(get_document_from_string response.body)
        end
      
	  api_use_cache :find_all
	    
The result of the method call will be marshalled and stored in a global hash for 30 minutes - Configuration to be added later. Any subsequent requests to that call will be retrieved from cache. The use case for this cache is when creating large collections from XML of a remote system. The request and creation time is often much longer than is desirable when the data is unlikely to change. 


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/ninjapanzer/xmlactiverecord/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

