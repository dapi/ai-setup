class Hotel < ApplicationRecord
  has_many :guests, dependent: :restrict_with_exception
  has_many :staff, dependent: :restrict_with_exception
  has_many :departments, dependent: :restrict_with_exception
  has_many :tickets, dependent: :restrict_with_exception
  has_many :knowledge_base_articles, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  def to_param
    slug
  end
end
