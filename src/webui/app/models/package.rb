class Package < ActiveXML::Base
   
  belongs_to :project

  handles_xml_element 'package'

  #cache variables
  attr_accessor :my_pro
  attr_accessor :my_architectures
  attr_accessor :linkinfo

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  def initialize(*args)
    super(*args)
    @bf_updated = false
    @pf_updated = false
    @df_updated = false
    @uf_updated = false
  end


  def my_project
    puts self.dump_xml
    self.my_pro ||= Project.find_cached(self.project)
    return self.my_pro
  end

  def to_s
    name.to_s
  end

  def save_file( opt = {} )
    file = opt[:file]
    logger.debug "storing file: #{file.inspect}, filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    put_opt = Hash.new
    put_opt[:package] = self.name
    put_opt[:project] = @init_options[:project]
    put_opt[:filename] = opt[:filename]
    put_opt[:comment] = opt[:comment]

    fc = FrontendCompat.new
    fc.put_file file.read, put_opt
    true
  end

  def remove_file( name )
    delete_opt = Hash.new
    delete_opt[:package] = self.name
    delete_opt[:project] = @init_options[:project]
    delete_opt[:filename] = name

    begin
       FrontendCompat.new.delete_file delete_opt
       true
    rescue ActiveXML::Transport::NotFoundError
       false
    end 
  end

  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to package #{self.name}"

    #add the new person
    add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]
  end

  #removes persons based on attributes
  def remove_persons( opt={} )
    xpath="//person"
    if not opt.empty?
      opt_arr = []
      opt.each do |k,v|
        opt_arr << "@#{k}='#{v}'"
      end
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.find(xpath).each {|e| e.remove! }
  end


  def set_url( new_url )
    logger.debug "set url #{new_url} for package #{self.name} (project #{self.project})"
    add_element 'url' unless has_element? :url
    url.text = new_url
    save
  end


  def remove_url
    logger.debug "remove url from package #{self.name} (project #{self.project})"
    data.find('//url').each { |e| e.remove! }
    save
  end


  def architectures
    return my_project.architectures
  end


  def repositories
    return my_project.repositories
 end

  
  def bugowner
    b = all_persons("bugowner")
    return b.first if b
    return nil
  end


  def all_persons( role )
    ret = Array.new
    each_person do |p|
      if p.role == role
        ret << p.userid.to_s
      end
    end
    return ret
  end

  def all_groups( role )
    ret = Array.new
    each_group do |p|
      if p.role == role
        ret << p.groupid.to_s
      end
    end
    return ret
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def self.exists? project_name, package_name
    if Package.find_cached( package_name, :project => project_name )
      return true
    else
      return false
    end
  end

  def linkinfo
    unless @linkinfo
      begin
        link = Directory.find_cached( :project => project, :package => name)
        @linkinfo = link.linkinfo if link.has_element? 'linkinfo'
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @linkinfo
  end

  def linked_to
    return [linkinfo.project, linkinfo.package] if linkinfo
    return []
  end

  def self.current_rev(project, package)
    dir = Directory.find_cached( :project => project, :package => package )
    return nil unless dir
    return dir.rev
  end

  def files
    # files whose name ends in the following extensions should not be editable
    no_edit_ext = %w{ .bz2 .dll .exe .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .pdf .pk3 .png .ps .rpm .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .xpm .xz .z .zip }
    files = []
    dir = Directory.find_cached( :project => project, :package => name )
    return files unless dir
    @linkinfo = dir.linkinfo if dir.has_element? 'linkinfo'
    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:ext] = Pathname.new(file[:name]).extname
      file[:editable] = ((not no_edit_ext.include?( file[:ext].downcase )) and file[:size].to_i < 2**20)  # max. 1 MB
      files << file
    end
    return files
  end

end

