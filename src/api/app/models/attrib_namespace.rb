# Specifies own namespaces of attributes

class AttribNamespace < ActiveRecord::Base
  has_many :attrib_types, :dependent => :destroy
  has_many :attrib_namespace_modifiable_bies, :class_name => 'AttribNamespaceModifiableBy', :dependent => :destroy


  class << self
    def list_all
      find :all
    end
  end

  def update_from_xml(node)
    self.transaction do
      self.attrib_namespace_modifiable_by.delete_all
      # store permission settings
      node.elements.each("modifiable_by") do |m|
          if not m.attributes["user"] and not m.attributes["group"]
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
          self.attrib_namespace_modifiable_bies << AttribNamespaceModifiableBy.new(p)
      end
      self.save
    end
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))
    if attrib_namespace_modifiable_bies.length > 0
      node.namespace(:name => self.name) do |an|
         attrib_namespace_modifiable_bies.each do |mod_rule|
           p={}
           p[:user] = mod_rule.user.login if mod_rule.user
           p[:group] = mod_rule.group.title if mod_rule.group
           an.modifiable_by(p)
         end
      end
    else
      node.namespace(:name => self.name)
    end
  end

  def self.anscache
    return @cache if @cache
    @cache = Hash.new
    find(:all).each do |ns|
      @cache[ns.name] = ns
    end
    return @cache
  end

  def anscache
    self.class.anscache
  end

  def after_create
    logger.debug "updating attrib namespace cache (new name '#{name}', id \##{id})"
    anscache[name] = self
  end

  def after_update
    logger.debug "updating attrib namespace cache (name for id \##{id} changed to '#{name}')"
    anscache.each do |k,v|
      if v.id == id
        anscache.delete k
        break
      end
    end
    anscache[name] = self
  end

  def after_destroy
    logger.debug "updating attrib namespace cache (name '#{name}' deleted)"
    anscache.delete name
  end

end
