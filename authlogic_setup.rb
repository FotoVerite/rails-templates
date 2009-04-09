load_template "http://github.com/FotoVerite/rails-templates/raw/master/basic.rb"
@project_name = ENV['name'] ? ENV['LEGOS'] : 'untitle'
# authorlogi-submodule
plugin 'authlogic', :git => 'git://github.com/binarylogic/authlogic.git', :submodule => true

# user_session resource
route 'map.resource :user_session'
route "map.activate '/activate/:activation_code', :controller => 'user', :action => 'activate', :activation_code => nil"

# Initialize submodules
git :submodule => "init"

# Set up session store initializer
   initializer 'session_store.rb', <<-END
 ActionController::Base.session = { :session_key => '_#{(1..6).map { |x| (65 + rand(26)).chr }.join}_session', :secret => '#{(1..40).map { |x| (65 + rand(26)).chr }.join}' }
 ActionController::Base.session_store = :active_record_store
 END
 
#run migratons
rake('db:sessions:create')
generate("authlogic", "user session")
generate('scaffold',
  'user', 
  'login:string',
  'email:string',
  "crypted_password:string",
  "password_salt:string",
  "activation_code:string",
  "email_authenticated:boolean",
  "persistence_token:string", 
  "login_count:integer",
  "last_request_at:datetime",
  "last_login_at:datetime",
  "current_login_at:datetime",
  "last_login_ip:string",
  "current_login_ip:string"
)

rake('db:migrate')


file 'app/controllers/user_sessions_controller.rb', <<-END
class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end
end
END

file 'app/controllers/users_controller.rb', <<-END
class UsersController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  
  acts_as_authentic
  
  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default dashboard_url
    else
      render :action => :new
    end
  end

  def show
    @user = @current_user
  end

  def edit
    @user = @current_user
  end

  def update
    @user = @current_user # makes our views "cleaner" and more consistent
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to dashboard_url
    else
      render :action => :edit
    end
  end
end
END

file 'app/controllers/application.rb', <<-END
class ApplicationController < ActionController::Base
  
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
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to dashboard_url
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
end
END

file 'app/model/user.rb', <<-END
class User < ActiveRecord::Base
before_create :make_activation_code

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end

protected

  def make_activation_code
    self.email_verification_code = self.class.make_token
  end
  
  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end
  
  def make_token
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
end
END

file 'app/controller/session.rb', <<-END
class Session < ActiveRecord::Base

   validate :validate_email_authenticated
   
   def validate_by_password
     self.attempted_record = search_for_record(find_by_login_method, send(login_field))
     if attempted_record.email_authenticated == false
     errors.add(email_authenticated, I18n.t('error_messages.email_authenticated',
     :default => "Email has not been authenticated, please check your email at #{attempted_record.email}")) if send(email_authenticated) == false
   end
  
end
END


file 'app/model/UserObserver.rb', <<-END
class UserObserver < ActiveRecord::Observer
  def after_create(user)
    UserMailer.deliver_signup_notification
  end

  def after_save(user)
    UserMailer.deliver_activation(user) if user.recently_activated?
  end
end
END

file 'app/model/UserMailer.rb', <<-END
def signup_notification(user)
  setup_email(user)
  @subject    += 'Please activate your new account'  
  @body[:url]  = "http://localhost:3000/activate/\#{user.activation_code}"  
end

def activation(user)
  setup_email(user)
  @subject    += 'Your account has been activated!'
  @body[:url]  = "http://localhost:3000/"
end

protected
  def setup_email(user)
    @recipients  = "\#{user.email}"
    @from        = "accounts@#{@project_name}.com"
    @subject     = "#{@project_name} - "
    @sent_on     = Time.now
    @body[:user] = user
  end
END

# Initialize submodules
git :submodule => "init"
 
# Commit all work so far to the repository
git :add => '.'
git :commit => "-a -m 'Added authlogic'"

puts "- Add an observer to config/environment.rb"
puts "config.active_record.observers = :user_observer"
