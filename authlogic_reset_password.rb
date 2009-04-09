load_template "http://github.com/FotoVerite/rails-templates/raw/master/authlogic_setup.rb"

generate(':migration', 
  "add_password_reset_fields_to_users",
  'perishable_token:string'
)

rake('db:migrate')

route 'map.resources :password_resets'

file 'app/controllers/password_resets_controller.rb', <<-END
class PasswordResetsController < ApplicationController
  def new
    render
  end

  def create
    @user = User.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = "Instructions to reset your password have been emailed to you. " +
        "Please check your email."
      redirect_to root_url
    else
      flash[:notice] = "No user was found with that email address"
      render :action => :new
    end
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
  
  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.deliver_password_reset_instructions(self)
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

def password_reset_instructions(user)
   setup_email(user)
   @subject    += "Password Reset Instructions"
   @body        = :edit_password_reset_url => edit_password_reset_url(\#{user.perishable_token})
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

file 'app/views/notifier/password_reset_instructions.erb', <<-END
A request to reset your password has been made.
If you did not make this request, simply ignore this email.
If you did make this request just click the link below:

<%= @edit_password_reset_url %>

If the above URL does not work try copying and pasting it into your browser.
If you continue to have problem please feel free to contact us.
END


file 'app/controllers/password_resets_controller.rb', <<-END
class PasswordResetsController < ActionController::Base

before_filter :load_user_using_perishable_token, :only => [:edit, :update]

def edit
  render
end

def update
  @user.password = params[:user][:password]
  @user.password_confirmation = params[:user][: password_confirmation]
  if @user.save
    flash[:notice] = "Password successfully updated"
    redirect_to account_url
  else
    render :action => :edit
  end
end

private
  def load_user_using_perishable_token
    @user = User.find_using_perishable_token(params[:id])
    unless @user
      flash[:notice] = "We're sorry, but we could not locate your account. " +
        "If you are having issues try copying and pasting the URL " +
        "from your email into your browser or restarting the " +
        "reset password process."
      redirect_to root_url
    end
  end

end
END

git :add => '.'
git :commit => "-a -m 'Added Reset_Password'"

puts "Succesfully added Reset_Password Option to Authlogic"
