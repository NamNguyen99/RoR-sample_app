class User < ApplicationRecord
    has_many :microposts, dependent: :destroy
    has_many :active_relationships, class_name: "Relationship", foreign_key: "follower_id", dependent: :destroy
    has_many :following, through: :active_relationships, source: :followed
    has_many :passive_relationships, class_name: "Relationship", foreign_key: "followed_id", dependent: :destroy
    has_many :followers, through: :passive_relationships
    attr_accessor :remember_token, :activation_token, :reset_token
    before_save :downcase_email
    before_create :create_activation_digest
    VALID_EMAIL_REGEX = /\A[\w+\-]+(\.[\w+\-]+)*@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    validates :name, presence: true, 
                    length: {maximum: 50}

    validates :email, presence: true, 
                    length: {maximum: 255}, 
                    format: {with: VALID_EMAIL_REGEX},
                    uniqueness: { case_sensitive: false}
    has_secure_password
    validates :password, presence:true, length: {minimum: 6}, allow_nil: true
    devise :omniauthable, omniauth_providers: %i[facebook]
    def User.digest(string)
        cost = ActiveModel::SecurePassword.min_cost ?
        BCrypt::Engine::MIN_COST :

        BCrypt::Engine.cost
        BCrypt::Password.create(string, cost: cost)
    end

    def User.new_token
        SecureRandom.urlsafe_base64
    end
    
    def remember
        self.remember_token = User.new_token
        update_attribute(:remember_digest, User.digest(remember_token))
    end
    def authenticated?(attribute, token)
        digest = send("#{attribute}_digest")
        return false if digest.nil?
        BCrypt::Password.new(digest).is_password?(token)
    end

    def forget
        update_attribute(:remember_digest, nil)
    end

    def activate 
        update_columns(activated: true, activated_at: Time.zone.now)
    end

    def send_activation_email
        UserMailer.account_activation(self).deliver_now
    end

    def create_reset_digest
        self.reset_token = User.new_token
        update_columns(reset_digest: User.digest(reset_token), reset_sent_at: Time.zone.now)
    end

    def send_password_reset_email
        UserMailer.password_reset(self).deliver_now
    end

    def password_reset_expired?
        reset_sent_at < 2.hours.ago
    end

    def feed
        Micropost.where("user_id IN (:following_ids) OR user_id= :user_id", following_ids: following_ids, user_id: id)
    end

    def follow other_user
        following << other_user
    end
    def unfollow other_user
        following.delete(other_user)
    end
    def following? other_user
        following.include?(other_user)
    end
    def self.from_omniauth(auth)
        where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
          user.email = auth.info.email
          user.password = User.new_token
          user.name = auth.info.name 
          user.image = auth.info.image 
          user.activated = true
          user.activated_at = Time.zone.now
          # If you are using confirmable and the provider(s) you use validate emails, 
          # uncomment the line below to skip the confirmation emails.
          #user.skip_confirmation!
        end
    end
    def self.new_with_session(params, session)
        super.tap do |user|
            if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
                user.email = data["email"] if user.email.blank?
            end
        end
    end
    private
    def downcase_email
        self.email = email.downcase
    end

    def create_activation_digest
        self.activation_token = User.new_token
        self.activation_digest = User.digest(activation_token)
    end
end
