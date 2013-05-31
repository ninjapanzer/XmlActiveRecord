XmlActiveRecord
===============

Can take XML and turn it into objects with ActiveRecord Style Macros

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
  api_attr_accessor_alias - Hash - Allows for failures in the naming convention of the API or a desired renaming of internal
    DSL to match to the XML. Aliases do not apply to has_many relationships at this time but will. Aliases follow the same
    naming conventions as standard api_attr_accessor's in that they are singular and underscored.
  api_xml_attributes - Hash - This allows for api_assume_parent to be configured. - This is already on the chopping block to be integrated into
  	the configuration of api_assume_parent since it is required.
  sanitize_xml(xmldoc, *things) - xmldoc, Array of strings - During testing it was found that some XML contains formatting characters which are 
  	rendered as undefined xml element nodes. To remove them before processing run this inside your processing method first.
