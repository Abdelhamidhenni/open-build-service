# This is the controller that provides CRUD functionality for the User model.
class ActiveRbac::UserController < ActiveRbac::ComponentController
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  # Use the configured layout.
  layout ActiveRbacConfig.config(:controller_layout)

  # We force users to use POST on the state changing actions.
  verify :method       => :post,
         :only         => [ :create, :update, :destroy ],
         :redirect_to  => { :action => 'list' },
         :add_flash    => { :error => 'You sent an invalid request!' }

  # We force users to use GET on all other methods, though.
  verify :method       => :get,
         :only         => [ :index, :list, :show, :new, :delete ],
         :redirect_to  => { :action => 'list' },
         :add_flash    => { :error => 'You sent an invalid request!' }
  

  # Simply redirects to #list
  def index
    redirect_to :action  => 'list'
  end

   def list
    if params[:onlyunconfirmed]
      @user_pages, @users = paginate :user, :conditions => [ "state = 5"], :order_by => "id", :per_page => 200
    else
      @user_pages, @users = paginate :user, :order_by => "login", :per_page => 25
    end
  end  # Displays a paginated table of users.

  # Show a user identified by the +:id+ path fragment in the URL.
  def show
    @user = User.find_by_id(params[:id].to_i)

    # if no user was found, try to find the user by login
    if @user.nil?
      @user = User.find_by_login(params[:id])
    end

    # if still no user was found, show error and redirect to list
    if @user.nil?
      flash[:notice] = 'This user could not be found.'
      redirect_to :action => 'list'
    end
  end

  # Displays a form to create a new user. Posts to the #create action.
  def new
    @user = User.new
  end

  # Creates a new user. +create+ is only accessible via POST and renders
  # the same form as #new on validation errors.
  def create
    # set password and password_confirmation into [:user] parameters
    params[:user][:password] = params[:password]
    params[:user][:password_confirmation] = params[:password_confirmation]
    
    @user = User.new(params[:user])

    # set password hash type seperatedly because it is protected
    @user.password_hash_type = params[:user][:password_hash_type]
    
    # assign properties to user
    if @user.save
      # set the user's roles to the roles from the parameters 
      params[:user][:roles] = [] if params[:user][:roles].nil?
      @user.roles = params[:user][:roles].collect { |i| Role.find(i) }

      # set the user's groups to the groups from the parameters 
      params[:user][:groups] = [] if params[:user][:groups].nil?
      @user.groups = params[:user][:groups].collect { |i| Group.find(i) }

      # the above should be successful if we reach here; otherwise we 
      # have an exception and reach the rescue block below
      flash[:notice] = 'User was created successfully.'
      redirect_to :action => 'show', :id => @user.to_param
    else
      render :action => 'new'
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the user identified by the :id parameter from the url fragment from
  # the database and displays an edit form with the user.
  def edit
    @user = User.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Updates a user record in the database. +update+ is only accessible via
  # POST and renders the same form as #edit on validation errors.
  def update
    @user = User.find(params[:id])

    # get an array of roles and set the role associations
    params[:user][:roles] = [] if params[:user][:roles].nil?
    roles = params[:user][:roles].collect { |i| Role.find(i) }
    @user.roles = roles

    # get an array of groups and set the group associations
    params[:user][:groups] = [] if params[:user][:groups].nil?
    groups = params[:user][:groups].collect { |i| Group.find(i) }
    @user.groups = groups

    # Set password and password_confirmation into [:user] parameters
    unless params[:password].to_s == ""
      params[:user][:password] = params[:password]
      params[:user][:password_confirmation] = params[:password_confirmation]
    end

    # Set password hash type seperatedly because it is protected
    @user.password_hash_type = params[:user][:password_hash_type] if params[:user][:password_hash_type] != @user.password_hash_type

    redir_to_opts = {:action => 'list'}
    
    if( params[:commit] =~ /Approve IChain Request/ )
      #grant user role
      user_role = Role.find_by_title("User")
      @user.roles << user_role unless @user.roles.include? user_role

      #set state to confirmed
      params[:user][:state] = @user.states['confirmed']

      redir_to_opts[:onlyunconfirmed] = 1
    end

    # Bulk-Assign the other attributes from the form.
    if @user.update_attributes(params[:user])
      flash[:notice] = 'User was successfully updated.'
      redirect_to redir_to_opts
    else
      render :action => 'edit'
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end
  
  # Loads the user specified by the :id parameters from the url fragment from
  # the database and displays a "Do you really want to delete it?" form. It
  # posts to #destroy.
  def delete
    @user = User.find(params[:id])
  rescue
    flash[:notice] = 'Invalid user specified!'
    redirect_to :action => 'list'
  end

  # Removes a user record from the database. +destroy+ is only accessible
  # via POST. If the answer to the form in #delete has not been "Yes", it 
  # redirects to the #show action with the selected's userp's ID.
  def destroy
    if not params[:yes].nil?
      User.find(params[:id]).destroy
      flash[:notice] = 'The user has been deleted successfully'
      redirect_to :action => 'list'
    else
      flash[:notice] = 'The user has not been deleted.'
      redirect_to :action => 'show', :id => params[:id]
    end
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This user could not be found.'
    redirect_to :action => 'list'
  end
end
