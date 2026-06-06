# frozen_string_literal: true

class AdminForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :name, :string
  attribute :invitation_token, :string
  attribute :reset_password_token, :string
  attribute :current_password, :string
end
