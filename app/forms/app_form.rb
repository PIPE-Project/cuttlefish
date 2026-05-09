# frozen_string_literal: true

class AppForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :integer
  attribute :name, :string
  attribute :click_tracking_enabled, :boolean, default: true
  attribute :open_tracking_enabled, :boolean, default: true
  attribute :custom_tracking_domain, :string
  attribute :from_domain, :string
  attribute :webhook_url, :string
end
