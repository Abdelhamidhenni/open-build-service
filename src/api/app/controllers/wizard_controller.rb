require 'wizard'

class WizardController < ApplicationController

  # GET/POST /source/<project>/<package>/_wizard
  def package_wizard
    prj_name = params[:project]
    pkg_name = params[:package]
    pkg = DbPackage.find_by_project_and_name(prj_name, pkg_name)

    # ACL(package_wizard): access behaves like package / project not existing
    raise DbPackage::PkgAccessError.new "" unless pkg

    if not @http_user.can_modify_package?(pkg)
      render_error :status => 403, :errorcode => "change_package_no_permission",
        :message => "no permission to change package"
      return
    end

    # ACL(package_wizard): source access gives permisson denied
    if pkg and pkg.disabled_for?('sourceaccess', nil, nil) and not @http_user.can_source_access?(pkg)
      render_error :status => 403, :errorcode => "source_access_no_permission",
      :message => "user #{params[:user]} has no read access to package #{pkg_name} in project #{prj_name}"
      return
    end

    logger.debug("package_wizard, #{params.inspect}")

    @wizard_xml = "/source/#{prj_name}/#{pkg_name}/wizard.xml"
    begin
      @wizard = Wizard.new(backend_get(@wizard_xml))
    rescue ActiveXML::Transport::NotFoundError
      @wizard = Wizard.new("")
    end
    @wizard["name"] = pkg_name
    @wizard["email"] = @http_user.email
    
    loop do
      questions = @wizard.run
      logger.debug("questions: #{questions.inspect}")
      if ! questions || questions.empty?
        break
      end
      @wizard_form = WizardForm.new(
                        "Creating package #{pkg_name} in project #{prj_name}")
      questions.each do |question|
        name = question.keys[0]
        if params[name] && ! params[name].empty?
          @wizard[name] = params[name]
          next
        end
        attrs = question[name]
        @wizard_form.add_entry(name, attrs["type"], attrs["label"],
                               attrs["legend"], attrs["options"], @wizard[name])
      end
      if ! @wizard_form.entries.empty?
        return render_wizard
      end
    end

    # create package container
    package = Package.find(params[:package], :project => params[:project])
    e = package.add_element "title"
    e.text = @wizard["summary"]
    e = package.add_element "description"
    e.text = @wizard["description"]
    package.save

    # create service file
    node = Builder::XmlMarkup.new(:indent=>2)
    xml = node.services() do |s|
       # download file
       m = @wizard["sourcefile"].split("://")
       protocol = m.first()
       host = m[1].split("/").first()
       path = m[1].split("/",2).last()
       s.service(:name => "download_url") do |d|
          d.param(protocol, :name => "protocol")
          d.param(host, :name => "host")
          d.param(path, :name => "path")
       end

       # run generator
       if @wizard["generator"] and @wizard["generator"] != "-"
          s.service(:name => "generator_#{@wizard['generator']}")
       end

       # run verification
    end

    logger.debug("package_wizard, #{xml.inspect}")
    logger.debug("package_wizard, #{xml}")
    backend_put("/source/#{params[:project]}/#{params[:package]}/_service?rev=upload", xml)
    backend_post("/source/#{params[:project]}/#{params[:package]}?cmd=commit&rev=upload&user=#{@http_user.login}", "")

    @wizard_form.last = true
    render_wizard
  end

  private
  def render_wizard
    if @wizard.dirty
      backend_put(@wizard_xml, @wizard.serialize)
    end
    render :template => "wizard", :status => 200
  end
end

# vim:et:ts=2:sw=2
