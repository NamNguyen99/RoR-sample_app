namespace :sending_email do
  desc "Send daily email to users"
  task email_sender: :environment do
    User.find_each do |user|
      UserMailer.active_notification(user).deliver if Time.now == Time.now.beginning_of_day
    end
  end

end
