require File.dirname(__FILE__) + '/../test_helper'
require 'tag_controller'

# Re-raise errors caught by the controller.
class TagController; def rescue_action(e) raise e end; end

class TagControllerTest < Test::Unit::TestCase
  
  fixtures :users, :db_projects, :db_packages, :tags, :taggings, :blacklist_tags
  
  def setup
    @controller = TagController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    #wrapper for testing private functions
    def @controller.private_s_to_tag(tag)
      s_to_tag(tag)
    end
    
    
    def @controller.private_taglistXML_to_tags(taglistXML)
      taglistXML_to_tags(taglistXML)
    end
    
    
    def @controller.private_create_relationship(object, tagCreator, tag)
      create_relationship(object, tagCreator, tag)
    end
    
    
    def @controller.private_save_tags(object, tagCreator, tags)
      save_tags(object, tagCreator, tags)
    end
    
    
    def @controller.private_taglistXML_to_tags(taglistXML)
      taglistXML_to_tags(taglistXML)
    end
  end
  
  
  def test_s_to_tag
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"
    
    #create a new tag
    t = @controller.private_s_to_tag("TagX")
    assert_kind_of Tag, t
    
    #find an existing tag
    t = @controller.private_s_to_tag("TagA")
    assert_kind_of Tag, t
    
    #expected exceptions 
    assert_raises (RuntimeError) {
      @controller.private_s_to_tag("IamNotAllowed")
    }
    
    assert_raises (RuntimeError) {
      @controller.private_s_to_tag("NotAllowedSymbol:?")
    }
    
  end
  
  
  def test_create_relationship_rollback
    u = User.find_by_login("tscholz")
    assert_kind_of User, u
    
    p = DbProject.find_by_name("home:tscholz")
    assert_kind_of DbProject, p
    
    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    #an exception should be thrown, because the record already exists
    assert_raises (ActiveRecord::StatementInvalid){
      @controller.private_create_relationship(p, u, t)
    }
  end
  
  
  def test_create_relationship
    u = User.find_by_login("tscholz")
    assert_kind_of User, u
    
    initial_user_tags = u.tags.clone
    assert_kind_of Array, initial_user_tags
    
    p = DbProject.find_by_name("home:tscholz")
    assert_kind_of DbProject, p
    
    
    #Precondition check: Tag "TagX" should not exist.
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"
    
    #create a tag for testing
    t = Tag.new
    t.name = "TagX"
    t.save
    
    #get this tag from the data base
    t = Tag.find_by_name("TagX")
    assert_kind_of Tag, t
    
    #create the relationship and store it in the join table
    assert_nothing_raised (ActiveRecord::StatementInvalid){
      @controller.private_create_relationship(p, u, t)
    }
    
    #reload the user, seems to be necessary
    u = User.find_by_login("tscholz")
    assert_kind_of User, u
    
    #testing the relationship.
    assert_equal "TagX", (u.tags - initial_user_tags)[0].name  
  end
  
  
  def test_save_tags
    u = User.find_by_login("tscholz")
    assert_kind_of User, u
    
    p = DbProject.find_by_name("home:tscholz")
    assert_kind_of DbProject, p
    
    #Precondition check: Tag "TagX" should not exist.
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"
    
    #Precondition check: Tag "TagY" should not exist.
    t = Tag.find_by_name("TagY")
    assert_nil t, "Precondition check failed, TagY already exists"
    
    #create a tag for testing
    tx = Tag.new
    tx.name = "TagX"
    tx.save
    
    #get this tag from the data base
    tx = Tag.find_by_name("TagX")
    assert_kind_of Tag, tx
    
    #create another tag for testing
    ty = Tag.new
    ty.name = "TagY"
    ty.save
    
    #get this tag from the data base
    ty = Tag.find_by_name("TagY")
    assert_kind_of Tag, ty
    
    t = Array.new
    t << tx
    t << ty
    
    assert_nothing_raised (ActiveRecord::StatementInvalid){
      @controller.private_save_tags(p, u, t)
    }
    
    assert_kind_of Tag, u.tags.find_by_name("TagX")
    assert_kind_of Tag, u.tags.find_by_name("TagY")  
  end
  
  
  def test_taglistXML_to_tags   
    u = User.find_by_login("tscholz")
    assert_kind_of User, u
    
    p = DbProject.find_by_name("home:tscholz")
    assert_kind_of DbProject, p
    
    #tags to create
    tags = ["TagX", "TagY", "TagZ", "IamNotAllowed"]
    
    #Precondition check: Tag "TagX" should not exist.
    tags.each do |tag|
      t = Tag.find_by_name(tag)
      assert_nil t, "Precondition check failed, #{tag} already exists"
    end 
    
    #and a existing tag
    tags << "TagA"
    
    #prepare the xml document for testing
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)      
    end
    
    #saves an initializes the tag objects 
    tags = Array.new
    unsaved_tags = Array.new
    
    #testing 
    assert_nothing_raised (ActiveRecord::StatementInvalid){
      tags, unsaved_tags = @controller.private_taglistXML_to_tags(xml.to_s)
    }
    
    assert_kind_of Array, tags
    assert_kind_of Array, unsaved_tags
    
    #4 tags saved and initialized
    assert_equal 4, tags.size
    #1 tag rejected
    assert_equal "IamNotAllowed", unsaved_tags[0] 
  end
  
  
  def test_get_project_tags
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown project
    get :project_tags, :project => "IamAnAlien" 
    assert_response 404
    
    #request tags for an existing project
    get :project_tags, :project => "home:tscholz" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => ""
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
  end
  
  
  def test_get_package_tags
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown project
    get :package_tags, :project => "IamAnAlien", :package => "MeToo"
    assert_response 404
    
    #request tags for an existing project
    get :package_tags, :project => "home:tscholz", :package => "TestPack" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :package => "TestPack",
      :user => ""
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
  end
  
  
  #  def test_put_project_tags
  #    prepare_request_with_user @request, "tscholz", "asdfasdf"
  #    
  #    #tags = ["TagX", "TagY", "TagZ", "IamNotAllowed", "TagA"]
  #    tags = ["TagX", "TagY", "TagZ", "TagA"]
  #    
  #    #prepare the xml document for testing
  #    xml = REXML::Document.new
  #    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
  #      xml.add_element( REXML::Element.new("tags") )
  #      xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
  #      tags.each do |tag|
  #        element = REXML::Element.new( 'tag' )
  #        element.add_attribute REXML::Attribute.new('name', tag)
  #        xml.root.add_element(element)      
  #    end
  #    
  #    
  #    #put tags for an existing project
  #    @request.env['RAW_POST_DATA'] = xml.to_s
  #    put :project_tags, :project => "home:tscholz" 
  #    assert_response :success
  #    
  #    
  #  end
  #  
  #  
 
  #This test is for testing the function get_tags_by_user_and_project
  #in the case of controller-internal usage of this function. 
  def test_get_tags_by_user_and_project_internal_use
    def @controller.params
      return {:user => "tscholz", :project => "home:tscholz"}
    end
    
    tags = @controller.get_tags_by_user_and_project( false )
    assert_kind_of Array, tags
    assert_equal 4, tags.size
    assert_equal 'TagA', tags[0].name
    assert_equal 'TagB', tags[1].name
    assert_equal 'TagC', tags[2].name 
    assert_equal 'TagF', tags[3].name 
  end
 
 
  #This test is for testing the function get_tags_by_user_and_package
  #in the case of controller-internal usage of this function.
  def test_get_tags_by_user_and_package_internal_use
    def @controller.params
      return {:user => "tscholz", :project => "home:tscholz",
      :package => "TestPack"}
    end
    
    tags = @controller.get_tags_by_user_and_package( false )
    assert_kind_of Array, tags
    assert_equal 4, tags.size
    assert_equal 'TagB', tags[0].name
    assert_equal 'TagC', tags[1].name
    assert_equal 'TagD', tags[2].name  
    assert_equal 'TagE', tags[3].name  
  end
  
  
  def test_get_tags_by_user_and_project
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown project
    get :get_tags_by_user_and_project, :project => "IamAnAlien",
    :user => "tscholz" 
    assert_response 404
 
    #request tags for an unknown user
    get :get_tags_by_user_and_project, :project => "home:tscholz",
    :user => "Alien" 
    assert_response 404   
    
    #request tags for an existing project
    get :get_tags_by_user_and_project, :project => "home:tscholz",
    :user => "tscholz" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    
    
    #request tags for another user than the logged on user
    get :get_tags_by_user_and_project, :project => "home:tscholz",
    :user => "fred" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => "fred"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 2, :only => { :tag => "tag" } }
    
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
  end
  
  
  def test_get_tags_by_user_and_package
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown project
    get :get_tags_by_user_and_package, :project => "IamAnAlien",
    :package => "MeToo",
    :user => "tscholz" 
    assert_response 404
    
    #request tags for an unknown package
    get :get_tags_by_user_and_package, :project => "home:tscholz",
    :package => "AlienPackage",
    :user => "tscholz" 
    assert_response 404
     
    #request tags for an unknown user
    get :get_tags_by_user_and_package, :project => "home:tscholz",
    :package => "TestPack",
    :user => "Alien" 
    assert_response 404   
    
    #request tags for an existing package
    get :get_tags_by_user_and_package, :project => "home:tscholz",
    :package => "TestPack",
    :user => "tscholz" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :package => "TestPack",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
    
    #request tags for another user than the logged on user
    get :get_tags_by_user_and_package, :project => "home:tscholz",
    :package => "TestPack",
    :user => "fred" 
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => "fred"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 1, :only => { :tag => "tag" } }
    
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
  end
  
  #This test gets all projects with tags by the logged on user tscholz
  def test_get_tagged_projects_by_user_1
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown user
    get :get_tagged_projects_by_user, :user => "IamAnAlienToo" 
    assert_response 404
    
    get :get_tagged_projects_by_user, :user => "tscholz"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :user => "tscholz"
    },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :children => { :count => 3, :only => { :tag => "project" } }
    #checking one of the three projects and each tag
    #TODO: check the others too
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"},
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    }
  end


  #This test gets all projects with tags by another user than the the logged on
  #user tscholz
  def test_get_tagged_projects_by_user_2
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :get_tagged_projects_by_user, :user => "fred"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :user => "fred"
    },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :children => { :count => 1, :only => { :tag => "project" } }
    #checking the project and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"},
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
  end
  

  #This test gets all packages with tags by the logged on user tscholz
  def test_get_tagged_packages_by_user_1
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown user
    get :get_tagged_packages_by_user, :user => "IamAnAlienToo" 
    assert_response 404
    
    
    get :get_tagged_packages_by_user, :user => "tscholz"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :user => "tscholz"
    },
    :child => { :tag => "package" }
    assert_tag :tag => "collection",
    :children => { :count => 1, :only => { :tag => "package" } }
    #checking the project and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
    }
  end


  #This test gets all packages with tags by another user than the the logged on
  #user tscholz
  def test_get_tagged_packages_by_user_2
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :get_tagged_packages_by_user, :user => "fred"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :user => "fred"
    },
    :child => { :tag => "package" }
    assert_tag :tag => "collection",
    :children => { :count => 1, :only => { :tag => "package" } }
    #checking the project and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
  end


  def test_get_projects_by_tag
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown tag
    get :get_projects_by_tag, :tag => "AlienTag"
    assert_response 404
    
    get :get_projects_by_tag, :tag => "TagA"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagA"
    },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :children => { :count => 3, :only => { :tag => "project" } }
    #checking one of the three projects and each tag
    #TODO: check the others too
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    }
  end
    
    
  #This test gets all projects tagged by the tree tags TagA, TagB, TagC
  #Result: only one project (home:tscholz)
  def test_get_projects_by_three_tags
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :get_projects_by_tag, :tag => "TagA::TagB::TagC"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagA::TagB::TagC" },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :children => { :count => 1, :only => { :tag => "project" } }
    #checking the project and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    }
  end
  
  
  #This test gets all projects tagged by the two tags TagA and TagC
  #Result: two projects (home:tscholz, kde)
  def test_get_projects_by_two_tags
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :get_projects_by_tag, :tag => "TagA::TagC"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagA::TagC" },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :children => { :count => 2, :only => { :tag => "project" } }
    
    #checking the project home:tscholz and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    }
    
    #checking the second project home:tscholz and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "kde",
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "kde",
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
  end
  
    
  def test_get_packages_by_tag
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown tag
    get :get_packages_by_tag, :tag => "AlienTag"
    assert_response 404
    
    get :get_packages_by_tag, :tag => "TagB"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagB"
    },
    :child => { :tag => "package" }
    assert_tag :tag => "collection",
    :children => { :count => 1, :only => { :tag => "package" } }
    #checking the package and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },                
                :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                }, 
                :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
    }
  end
  
  
  def test_get_objects_by_tag
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #request tags for an unknown tag
    get :get_objects_by_tag, :tag => "AlienTag"
    assert_response 404
    
    get :get_objects_by_tag, :tag => "TagB"
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagB"
    },
    :child => { :tag => "project" }
    assert_tag :tag => "collection",
    :attributes => { :tag => "TagB"
    },
    :child => { :tag => "package" }
    #checking the project and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "project",
                :attributes => {:name => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    }
    #checking the package and each tag
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },               
                :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    }
    assert_tag  :tag => "collection",
    :child => { :tag => "package",
                :attributes => {:name => "TestPack",
                  :project => "home:tscholz"
                },
                :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
    }
  end
  
  
  def test_tagcloud_wrong_parameter    
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #parameter steps
    get :tagcloud, :steps => -1
    assert_response 404
    
    get :tagcloud, :steps => 101
    assert_response 404
    
    get :tagcloud, :steps => 6
    assert_response :success
    
    
    #parameter distribution(_method)
    get :tagcloud, :distribution => 'Alien'
    assert_response 404
    
    get :tagcloud, :distribution => 'raw'
    assert_response :success
    
    get :tagcloud, :distribution => 'logarithmic'
    assert_response :success
    
    get :tagcloud, :distribution => 'linear'
    assert_response :success

  end

  
  def test_tagcloud_raw
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :tagcloud, :distribution => 'raw', :limit => 4
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "raw",
                     :steps => 6, #thats the default
                     :user => ""
    },
    :children => { :count => 4, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagA", :count => 3} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :count => 4} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :count => 4} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagF", :count => 1} }    
  end  


  def test_tagcloud_linear
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :tagcloud, :distribution => 'linear', :steps => 10, :limit => 4
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "linear",
                     :steps => 10,
                     :user => ""
    },
    :children => { :count => 4, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagA", :size => 7} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :size => 10} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :size => 10} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagF", :size => 0} }
  end
  
  
  def test_tagcloud_logarithmic
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :tagcloud, :distribution => 'logarithmic', :steps => 12, :limit => 6
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "logarithmic",
                     :steps => 12,
                     :user => ""
    },
    :children => { :count => 6, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagA", :size => 10} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagD", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagE", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagF", :size => 0} }
  end
  
  
  def test_tagcloud_by_user
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    get :tagcloud, :distribution => 'logarithmic', :steps => 12, :user => 'tscholz'
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "logarithmic",
                     :steps => 12,
                     :user => "tscholz"
    },
    :children => { :count => 6, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagA", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :size => 8} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagD", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagE", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagF", :size => 0} }
    
    
    prepare_request_with_user @request, "fred", "geröllheimer"
    
    get :tagcloud, :distribution => 'logarithmic', :steps => 12, :user => 'fred'
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "logarithmic",
                     :steps => 12,
                     :user => "fred"
    },
    :children => { :count => 2, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :size => 0} }
  
  
    #get the tag-cloud from another user
    get :tagcloud, :distribution => 'logarithmic', :steps => 12, :user => 'tscholz'
    assert_response :success
    
    #checking response-data 
    assert_tag :tag => "tagcloud",
    :attributes => { :distribution_method => "logarithmic",
                     :steps => 12,
                     :user => "tscholz"
    },
    :children => { :count => 6, :only => { :tag => "tag"} }
    
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagA", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagB", :size => 8} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagC", :size => 12} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagD", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagE", :size => 0} }
    assert_tag :tag => "tagcloud",
    :child => { :tag => "tag", :attributes => {:name => "TagF", :size => 0} }
    
    
    #unknown user
    get :tagcloud, :distribution => 'logarithmic', :steps => 12, :user => 'Alien'
    assert_response 404  
  end
  
  
  def test_tags_by_user_and_object_put_for_a_project
    
    #Precondition check: Get all tags for tscholz and the home:project.  
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get :get_tags_by_user_and_project, :project => 'home:tscholz',
    :user => 'tscholz'
    assert_response :success
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagF"} }
    
    
    #tags to create  
    tags = ["TagX", "TagY", "TagZ", "TagA"]  
    #prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)      
    end
    
    #add tags
    @request.env['RAW_POST_DATA'] = xml.to_s
    put :tags_by_user_and_object, :project => 'home:tscholz', :user => 'tscholz'
    assert_response :success
    
    
    # Get data again and check that tags where added or removed 
    get :get_tags_by_user_and_project, :project => 'home:tscholz',
    :user => 'tscholz'
    assert_response :success
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagX"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagY"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagZ"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagA"} }    
  end
  
  
  def test_tags_by_user_and_object_put_for_a_package
    
    #Precondition check: Get all tags for tscholz and a package.  
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get :get_tags_by_user_and_package, :project => 'home:tscholz',
    :package => 'TestPack', :user => 'tscholz'
    assert_response :success
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :package => "TestPack",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagC"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagD"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagE"} }
    
    
    #tags to create  
    tags = ["TagX", "TagY", "TagZ", "TagB"]  
    #prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)      
    end
    
    #add tags
    @request.env['RAW_POST_DATA'] = xml.to_s
    put :tags_by_user_and_object, :project => 'home:tscholz', 
    :package => "TestPack",
    :user => 'tscholz'
    assert_response :success
    
    
    # Get data again and check that tags where added or removed 
    get :get_tags_by_user_and_package, :project => 'home:tscholz',
    :package => 'TestPack',
    :user => 'tscholz'
    assert_response :success
    #checking response-data 
    assert_tag :tag => "tags",
    :attributes => { :project => "home:tscholz",
      :package => "TestPack",
      :user => "tscholz"
    },
    :child => { :tag => "tag" }
    assert_tag :tag => "tags",
    :children => { :count => 4, :only => { :tag => "tag" } }
    #checking each tag
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagX"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagY"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagZ"} }
    assert_tag  :tag => "tags",
    :child  =>  {:tag => "tag", :attributes => {:name => "TagB"} }    
  end
  
  
  #test for writing tags for another user than the logged in user <- forbidden
  def test_tags_by_user_and_object_put_as_invalid_user
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
    #tags to create  
    tags = ["TagX", "TagY", "TagZ", "TagB"]  
    #prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)      
    end
    
    @request.env['RAW_POST_DATA'] = xml.to_s
    
    #put request for an unknown user
    put :tags_by_user_and_object, :project => 'home:tscholz', 
    :package => "TestPack",
    :user => 'Alien'
    assert_response 404
    
    #put request for another user than the logged on user.
    put :tags_by_user_and_object, :project => 'home:tscholz', 
    :package => "TestPack",
    :user => 'fred'
    assert_response 403
  end
  
  
  def test_tags_by_user_and_object_put_for_invalid_objects
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    
     #tags to create  
    tags = ["TagX", "TagY", "TagZ", "TagB"]  
    #prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:tscholz")       
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)      
    end
    
    @request.env['RAW_POST_DATA'] = xml.to_s
    
    #put request for an unknown project
    put :tags_by_user_and_object, :project => 'AlienProject', 
    :user => 'tscholz'
    assert_response 404
    
    #put request for an unknown package
    put :tags_by_user_and_object, :project => 'home:tscholz', 
    :package => "AlienPackage",
    :user => 'tscholz'
    assert_response 404
  end
  
end
