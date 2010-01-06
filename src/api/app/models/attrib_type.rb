# Attribute definition as part of project meta data
# This is always inside of an attribute namespace

class AttribType < ActiveRecord::Base
  belongs_to :attrib_namespace

  has_many :attribs, :dependent => :destroy
  has_many :default_values, :class_name => 'AttribDefaultValue', :dependent => :destroy
  has_many :allowed_values, :class_name => 'AttribAllowedValue', :dependent => :destroy
  has_many :attrib_type_modifiable_bies, :class_name => 'AttribTypeModifiableBy', :dependent => :destroy

  class << self
    def list_all(namespace=nil)
      if namespace
        find :all, :joins => "JOIN attrib_namespaces an ON attrib_types.attrib_namespace_id = an.id", :conditions => ["an.name = BINARY ?", namespace]
      else
        find :all
      end
    end

    def find_by_name(name)
      name_parts = name.split /:/
      if name_parts.length != 2
        raise RuntimeError, "attribute '#{name}' must be in the $NAMESPACE:$NAME style"
      end
      find_by_namespace_and_name(name_parts[0], name_parts[1])
    end
  
    def find_by_namespace_and_name(namespace, name)
      unless namespace and name
        raise RuntimeError, "attribute must be in the $NAMESPACE:$NAME style"
      end
      find :first, :joins => "JOIN attrib_namespaces an ON attrib_types.attrib_namespace_id = an.id", :conditions => ["attrib_types.name = BINARY ? and an.name = BINARY ?", name, namespace]
    end
  end

  def namespace
    read_attribute :attrib_namespace
  end
 
  def namespace=(val)
    write_attribute :attrib_namespace, val
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))
     p = {}
     p[:name]      = self.name
     p[:namespace] = attrib_namespace.name
     node.definition(p) do |attr|

       if default_values.length > 0
         attr.default do |default|
           default_values.each do |def_val|
             default.value def_val.value
           end
         end
       end

       if allowed_values.length > 0
         attr.allowed do |allowed|
           allowed_values.each do |all_val|
             allowed.value all_val.value
           end
         end
       end

       if self.value_count
         attr.count self.value_count
       end

       if attrib_type_modifiable_bies.length > 0
         attrib_type_modifiable_bies.each do |mod_rule|
           p={}
           p[:user] = mod_rule.user.login if mod_rule.user 
           p[:group] = mod_rule.group.title if mod_rule.group 
           p[:role] = mod_rule.role.title if mod_rule.role 
           attr.modifiable_bies(p)
         end
       end

     end
  end

  def update_from_xml(node)
    self.transaction do
      #
      # defined permissions
      #
      self.attrib_type_modifiable_bies.delete_all
      # store permission setting
      node.elements.each("modifiable_by") do |m|
          if not m.attributes["user"] and not m.attributes["group"] and not m.attributes["role"]
            raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
          end
          p={}
          if m.attributes["user"]
            p[:user] = User.find_by_login(m.attributes["user"])
            raise RuntimeError, "Unknown user '#{m.attributes["user"]}' in modifiable_by element" if not p[:user]
          end
          if m.attributes["group"]
            p[:group] = Group.find_by_title(m.attributes["group"])
            raise RuntimeError, "Unknown group '#{m.attributes["group"]}' in modifiable_by element" if not p[:group]
          end
          if m.attributes["role"]
            p[:role] = Role.find_by_title(m.attributes["role"])
            raise RuntimeError, "Unknown role '#{m.attributes["role"]}' in modifiable_by element" if not p[:role]
          end
          self.attrib_type_modifiable_bies << AttribTypeModifiableBy.new(p)
      end

      #
      # attribute type definition
      #
      # set value counter (this number of values must exist, not more, not less)
      self.value_count = nil
      node.elements.each("count") do |c|
        self.value_count = c.text
      end

      # default values of a attribute stored
      self.default_values.delete_all
      node.elements.each("default") do |d|
        self.default_values << AttribDefaultValue.new(:value => d.text)
      end

      # list of allowed values
      self.allowed_values.delete_all
      node.elements.each("allowed") do |d|
        self.allowed_values << AttribAllowedValue.new(:value => d.text)
      end

      self.save
    end
  end
end
