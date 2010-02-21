require "bard/template/helper"

# GEMS
#gem 'bcrypt-ruby', :lib => 'bcrypt' # used by authlogic
gem 'authlogic'

rake "gems:install"
#rake("gems:unpack")

# APPCTRL/HELPER/FLASH
file_inject 'app/controllers/application_controller.rb',
"class ApplicationController < ActionController::Base", <<-END
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end
    
    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in!"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out!"
        redirect_to account_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
    
END

# AUTHLOGIC
log 'authlogic', 'setup' 
generate :session, 'user_session' 

# ROUTES
route %q(map.resources :password_resets)
route %q(map.resources :users)
route %q(map.resource :user_session, :except => [:edit, :update])
route %q(map.login "login", :controller => "user_sessions", :action => "new")
route %q(map.logout "logout", :controller => "user_sessions", :action => "destroy")
route %q(map.register '/register/:activation_code', :controller => 'activations', :action => 'new')
route %q(map.activate '/activate/:id', :controller => 'activations', :action => 'create')
route %q(map.resource :account, :controller => "users")

# CONTROLLERS
file 'app/controllers/user_sessions_controller.rb', <<-END
class UserSessionsController < ResourceController::Base
  actions :new, :create, :destroy

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  create do
    flash "Successfully logged in." 
    wants.html { redirect_back_or_default account_url }

    failure.flash "Bad email or password!"
  end

  def destroy
    @user_session = UserSession.find
    @user_session.destroy
    flash[:notice] = "Successfully logged out."
    redirect_to root_url
  end
end
END


file 'app/controllers/users_controller.rb', <<-END
class UsersController < ResourceController::Base
  actions :new, :create, :show, :edit, :update
  
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]

  def create
    @user = User.new

    if @user.signup!(params)
      @user.deliver_activation_instructions!
      flash[:notice] = "Thanks for signing up! Please check your email for activation instructions."
      redirect_to root_url
    else
      render :action => :new
    end
  end

  update.wants.html { redirect_to account_path }

  private
    def object
      @object ||= current_user
    end
end
END

file 'app/controllers/activations_controller.rb', <<-END
class ActivationsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  
  def new
    @user = User.find_using_perishable_token(params[:activation_code], 1.week) || (raise Exception)
    raise Exception if @user.active?
  end

  def create
    @user = User.find(params[:id])

    raise Exception if @user.active?

    if @user.activate!(params)
      @user.deliver_activation_confirmation!
      flash[:notice] = "Your account has been activated!"
      redirect_to account_url
    else
      render :action => :new
    end
  end

end
END

file 'app/controllers/password_resets_controller.rb', <<-END
class PasswordResetsController < ApplicationController
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  before_filter :require_no_user
  
  def new
    render
  end
  
  def create
    @user = User.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = "Check your email for password reset instructions."
      redirect_to root_url
    else
      flash[:notice] = "No account found for \#{params[:email]}."
      render :action => :new
    end
  end
  
  def edit
    render
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      flash[:notice] = "Your password has been reset!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = User.find_using_perishable_token(params[:id])
      unless @user
        flash[:notice] = "Bad key."
        redirect_to root_url
      end
    end
end

END


# MIGRATIONS
file "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_users.rb", <<-END
class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users, :force => true do |t|
      t.string    :email, :null => false
      t.string    :crypted_password, :default => nil, :null => true
      t.string    :password_salt, :default => nil, :null => true
      t.string    :perishable_token, :default  => "", :null => false
      t.string    :persistence_token, :null => false
      t.integer   :login_count, :default => 0, :null => false
      t.datetime  :last_request_at
      t.datetime  :last_login_at
      t.datetime  :current_login_at
      t.string    :last_login_ip
      t.string    :current_login_ip
      t.boolean   :active, :default => false      
      t.timestamps
    end
    
    add_index :users, :email
    add_index :users, :persistence_token
    add_index :users, :perishable_token    
    add_index :users, :last_request_at
  end

  def self.down
    drop_table :users
  end
end
END

file "app/models/user.rb", <<-END
class User < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation
  
  acts_as_authentic do |c|
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
  end
                    
  def has_no_credentials?
    self.crypted_password.blank? && self.openid_identifier.blank?
  end

  # User creation/activation
  def signup!(params)
    self.email = params[:user][:email]
    save_without_session_maintenance
  end
  
  def activate!(params)
    self.active = true
    self.password = params[:user][:password]
    self.password_confirmation = params[:user][:password_confirmation]
    save
  end

  # Email notifications
  def deliver_password_reset_instructions!
    reset_perishable_token!
    UserNotifier.deliver_password_reset_instructions(self)
  end
  
  def deliver_activation_instructions!
    reset_perishable_token!
    UserNotifier.deliver_activation_instructions(self)
  end
  
  def deliver_activation_confirmation!
    reset_perishable_token!
    UserNotifier.deliver_activation_confirmation(self)
  end
  
  # Helper methods
  def active?
    active
  end
  
end
END

# VIEWS
file 'app/views/activations/new.html.haml', <<-END
%h1 Activate your account
- form_for @user, :url => activate_path(@user.id), :html => { :method => :post} do |form| 
  = form.error_messages
  = render :partial => "form", :locals => { :form => form }
  = form.submit "Activate"
END

file 'app/views/activations/_form.html.haml', <<-END
= form.label :email
%br
=h @user.email
%br
%br
= form.label :password, "Choose a password"
%br
= form.password_field :password
%br
%br
= form.label :password_confirmation
%br
= form.password_field :password_confirmation
%br
%br
END

file 'app/views/user_sessions/new.html.haml', <<-END
%h1 Login
- form_for @user_session, :url => user_session_path do |f|
  = f.error_messages
  = f.label :email
  %br
  = f.text_field :email
  %br
  %br
  = f.label :password
  %br
  = f.password_field :password
  %br
  %br
  = f.check_box :remember_me
  = f.label :remember_me
  %br
  %br
  = f.submit "Login"

= link_to "Sign up", new_account_path
END

file 'app/views/password_resets/new.html.haml', <<-END
%h1 Forgot your password?

- form_tag password_resets_path do 
  %label Email address
  %br
  = text_field_tag :email
  %br
  = submit_tag "Reset"
END

file 'app/views/password_resets/edit.html.haml', <<-END
%h1 Choose a new password

- form_for @user, :url => password_reset_path, :method => :put do |f|
  = f.error_messages
  %br
  = f.label :password
  %br
  = f.password_field :password
  %br
  %br  
  = f.label :password_confirmation
  %br  
  = f.password_field :password_confirmation
  %br
  %br
  = f.submit "Save new password"
END


file 'app/views/users/_form.html.haml', <<-END
= form.label :email
%br
= form.text_field :email
%br
%br
- unless form.object.new_record?
  = form.label :password, form.object.new_record? ? nil : "Change password"
  %br
  = form.password_field :password
  %br
  %br
  = form.label :password_confirmation
  %br
  = form.password_field :password_confirmation
  %br
  %br
END

file 'app/views/users/edit.html.haml', <<-END
%h1 My Account

- form_for @user, :url => account_path do |f|
  = f.error_messages
  = render :partial => "form", :object => f
  = f.submit "Update"
%br
= link_to "My account", account_path
END

file 'app/views/users/new.html.haml', <<-END
%h1 Sign Up

- form_for @user, :url => account_path do |f|
  = f.error_messages
  = render :partial => "form", :object => f
  = f.submit "Sign Up"
END

file 'app/views/users/show.html.haml', <<-END
%p
  %b
    Email:
  = h @user.email
%p
  %b
    Login count:
  = h @user.login_count
%p
  %b
    Last request at:
  = h @user.last_request_at
%p
  %b
    Last login at:
  = h @user.last_login_at
%p
  %b
    Current login at:
  = h @user.current_login_at
%p
  %b
    Last login ip:
  = h @user.last_login_ip
%p
  %b
    Current login ip:
  = h @user.current_login_ip
= link_to 'Edit', edit_account_path

END

# AUTHLOGIC Email Notifier
generate :mailer, "user_notifier" 
file 'app/models/user_notifier.rb', <<-END 
class UserNotifier < ActionMailer::Base

  default_url_options[:host] = "localhost:3000"

  def activation_confirmation(user)
    setup_email   user
    subject       "[#{project_name}] Account activated!"
    body          :root_url => root_url
  end

  def activation_instructions(user)
    setup_email   user
    subject       "[#{project_name}] Welcome!"
    body          :account_activation_url => register_url(user.perishable_token)
  end

  def password_reset_instructions(user)
    setup_email   user
    subject       "[#{project_name}] Forgot your password?"
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)
  end

  
  protected
  def setup_email(user)      
    recipients   user.email
    from         "#{project_name} Notifier <noreply@#{project_name}>"
    sent_on      Time.now
    body         :user => user
  end
end
END

# Authlogic mailer views (RO)
file 'app/views/user_notifier/activation_instructions.erb', <<-END 
Thanks for signing up!

Please visit the following link to activate your account: <%= @account_activation_url %>
END

file 'app/views/user_notifier/activation_confirmation.erb', <<-END
Your account has been activated!

You may log in here: <%= @root_url %>
END

file 'app/views/user_notifier/password_reset_instructions.erb', <<-END
Forgot your password?

Visit the following link to change it to something new: <%= @edit_password_reset_url %>
END

# DATABASE & MIGRATIONS
rake "db:migrate" 

git :add => "."
git :commit => "-am'added authentication.'"
