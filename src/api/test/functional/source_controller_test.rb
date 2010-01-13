require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

FIXTURES = [
  :static_permissions,
  :roles,
  :roles_static_permissions,
  :roles_users,
  :users,
  :db_projects,
  :db_packages,
  :bs_roles,
  :repositories,
  :path_elements,
  :project_user_role_relationships
]

class SourceControllerTest < ActionController::IntegrationTest 
  fixtures *FIXTURES
  
  def setup
    @controller = SourceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # make a backup of the XML test files
    # backup_source_test_data
    setup_mock_backend_data
  end

  def test_get_projectlist
    prepare_request_with_user @request, "tom", "thunder"
    get "/source"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :only => { :tag => "entry" } }
  end
  

  def test_get_packagelist
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2, :only => { :tag => "entry" } }
  end


  # non-existing project should return 404
  def test_get_illegal_project
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde2000/_meta"
    assert_response 404
  end


  # non-existing project-package should return 404
  def test_get_illegal_projectfile
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/kdelibs2000/_meta"
    assert_response 404
  end


  def test_get_project_meta
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "kde4" }
  end
  

  def test_get_package_filelist
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/kdelibs"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 3, :only => { :tag => "entry" } }
  end
  
  def test_get_package_meta
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "kdelibs" }
  end
  
  # project_meta does not require auth
  def test_invalid_user
    prepare_request_with_user @request, "king123", "sunflower"
    get "/source/kde4/_meta"
    assert_response 200
  end
  
  def test_valid_user
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/_meta"
    assert_response :success
  end
  
  
  
  def test_put_project_meta_with_invalid_permissions
    prepare_request_with_user @request, "tom", "thunder"
    # The user is valid, but has weak permissions
    
    # Get meta file
    get "/source/kde4/_meta"
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4"), doc.to_s
    assert_response 403
    
  end
  
  
  def test_put_project_meta
    prepare_request_with_user @request, "king", "sunflower"
    do_change_project_meta_test
    prepare_request_with_user @request, "fred", "geröllheimer"
    do_change_project_meta_test
  end
  

  def do_change_project_meta_test
   # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:action => :project_meta, :project => "kde4"), doc.to_s
    assert_response :success
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that it is the changed data
    get url_for(:action => :project_meta, :project => "kde4")
    doc = REXML::Document.new( @response.body )
    d = doc.elements["//description"]
    assert_equal new_desc, d.text
  
  end
  private :do_change_project_meta_test
  
  
  
  def test_create_project_meta
    do_create_project_meta_test("king", "sunflower")
  end
  
  
  def do_create_project_meta_test (name, pw)
    prepare_request_with_user(@request, name, pw)
    # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    xml = @response.body
    doc = REXML::Document.new( xml )
    # change name to kde5: 
    d = doc.elements["/project"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kde5' ) 
    put url_for(:controller => :source, :action => :project_meta, :project => "kde5"), doc.to_s
    assert_response(:success, message="--> #{name} was not allowed to create a project")
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :project_meta, :project => "kde5")
    assert_response :success
    assert_select "project[name=kde5]"
    assert_select "person[userid=king][role=maintainer]", {}, "Creator was not added as project maintainer"
  end
  private :do_create_project_meta_test
  
  
  
  
  def test_put_invalid_project_meta
    prepare_request_with_user @request, "fred", "geröllheimer"

   # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4"), doc.to_s + "</xml>"
    assert_response 400

    prepare_request_with_user @request, "king", "sunflower"
    # write to illegal location: 
    put url_for(:controller => :source, :action => :project_meta, :project => "../source/bang"), doc.to_s
    assert_response( 404, "--> Was able to create project at illegal path")
    put url_for(:controller => :source, :action => :project_meta)
    assert_response( 400, "--> Was able to create project at illegal path")
    put url_for(:controller => :source, :action => :project_meta, :project => ".")
    assert_response( 400, "--> Was able to create project at illegal path")
    
    #must not create a project with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :project_meta, :project => "kde5"), doc.to_s
    assert_response( 400, "--> Was able to create project with different project-name in _meta.xml")    
    
    #TODO: referenced repository names must exist
    
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4" )
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end
  
  
  
  
  def test_put_package_meta_with_invalid_permissions
    prepare_request_with_user @request, "tom", "thunder"
    # The user is valid, but has weak permissions
    
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s
    assert_response 403
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new(( @response.body )).to_s)    
  end
  
  

  def do_change_package_meta_test
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s
    assert_response(:success, "--> Was not able to update kdelibs _meta")   
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    # Get data again and check that it is the changed data
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["//description"]
    #ignore updated change
    newdoc.root.attributes['updated'] = doc.root.attributes['updated']
    assert_equal new_desc, d.text
    assert_equal doc.to_s, newdoc.to_s
  end
  private :do_change_package_meta_test



  # admins, project-maintainer and package maintainer can edit package data
  def test_put_package_meta
      prepare_request_with_user @request, "king", "sunflower"
      do_change_package_meta_test
      prepare_request_with_user @request, "fred", "geröllheimer"
      do_change_package_meta_test
      prepare_request_with_user @request, "fredlibs", "geröllheimer"
      do_change_package_meta_test
  end



  def test_create_package_meta
    # user without any special roles
    prepare_request_with_user @request, "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    #change name to kdelibs2
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kdelibs2' ) 
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2"), doc.to_s
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )
    
    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2")
    assert_response :success
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["/package"]
    assert_equal(d.attribute('name').value(), 'kdelibs2', message="Project name was not set to kdelibs2")
    #d = newdoc.elements["//person[@role='maintainer' and @userid='fred']"]
    #assert_not_nil(d, message="--> Creator was not added automatically as package-maintainer")  
  end


  def test_put_invalid_package_meta
    prepare_request_with_user @request, "fredlibs", "geröllheimer"
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s + "</xml>"
    assert_response 400

    prepare_request_with_user @request, "king", "sunflower"
    # write to illegal location: 
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "../bang"), doc.to_s
    assert_response( 404, "--> Was able to create package at illegal path")
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4"), doc.to_s
    assert_response( 404, "--> Was able to create package at illegal path")
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "."), doc.to_s
    assert_response( 400, "--> Was able to create package at illegal path")
    
    #must not create a package with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2000"), doc.to_s
    assert_response( 400, "--> Was able to create package with different project-name in _meta.xml")     
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end



  def test_read_file
    prepare_request_with_user @request, "tom", "thunder"
    get "/source/kde4/kdelibs/my_patch.diff"
    assert_response :success
    assert_equal( @response.body.to_s, "argl\n" )
    
    get "/source/kde4/kdelibs/BLUB"
    #STDERR.puts(@response.body)
    assert_response 404
    assert_tag( :tag => "status" )
    
    get "/source/kde4/kdelibs/../kdebase/_meta"
    #STDERR.puts(@response.body)
    assert_response( 404, "Was able to read file outside of package scope" )
    assert_tag( :tag => "status" )
    
  end
  


  def add_file_to_package
    teststring = "&;" 
    put "/source/kde4/kdelibs/testfile", teststring
    assert_response :success
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )
  
    get "/source/kde4/kdelibs/testfile"
    assert_response :success
    assert_equal( @response.body.to_s, teststring )
  end
  private :add_file_to_package
  
  
  
  def test_add_file_to_package
    prepare_request_with_user @request, "fredlibs", "geröllheimer"
    add_file_to_package
    prepare_request_with_user @request, "fred", "geröllheimer"
    add_file_to_package
    prepare_request_with_user @request, "king", "sunflower"
    add_file_to_package
  
    # write without permission: 
    prepare_request_with_user @request, "tom", "thunder"
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff")
    assert_response :success
    origstring = @response.body.to_s
    teststring = "&;"
    @request.env['RAW_POST_DATA'] = teststring
    put url_for(:action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff")
    assert_response( 403, message="Was able to write a package file without permission" )
    assert_tag( :tag => "status" )
    
    # check that content is unchanged: 
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff")
    assert_response :success
    assert_equal( @response.body.to_s, origstring, message="Package file was changed without permissions" )
  end
  
  def test_remove_project1
    ActionController::IntegrationTest::reset_auth 
    delete "/source/kde4"
    assert_response 401

    prepare_request_with_user @request, "fredlibs", "geröllheimer"
    delete "/source/kde4" 
    assert_response :success
  end

  def test_remove_project2
    prepare_request_with_user @request, "tom", "thunder" 
    delete "/source/home:coolo"
    assert_response 403
    assert_select "status[code] > summary", /Unable to delete project home:coolo; following repositories depend on this project:/

    delete "/source/home:coolo", :force => 1
    assert_response :success

    # verify the repo is updated
    get "/source/home:coolo:test/_meta"
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.repository.name, "home_coolo"
    assert_equal node.repository.path.project, "deleted"
    assert_equal node.repository.path.repository, "gone"
  end

  def test_branch_package
    ActionController::IntegrationTest::reset_auth 
    post "/source/home:tscholz/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 401

    prepare_request_with_user @request, "fredlibs", "geröllheimer"
    post "/source/home:tscholz/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 403
 
    prepare_request_with_user @request, "tom", "thunder"
    post "/source/home:tscholz/TestPack", :cmd => :branch, :target_project => "home:coolo:test"    
    assert_response :success
    get "/source/home:coolo:test/TestPack/_meta"
    assert_response :success

    # now with a new project
    post "/source/home:tscholz/TestPack", :cmd => :branch
    assert_response :success
    
    get "/source/home:tom:branches:home:tscholz/TestPack/_meta"
    assert_response :success

    get "/source/home:tom:branches:home:tscholz/_meta"
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.repository.name, "standard"
    assert_equal ret.repository.path.repository, "standard"
    assert_equal ret.repository.path.project, "home:tscholz"
  end

  def teardown  
    # restore the XML test files
    # restore_source_test_data
    teardown_mock_backend_data
  end
  
end
