# == Schema Information
#
# Table name: catalogs
#
#  created_at       :datetime         not null
#  deactivated_at   :datetime
#  id               :integer          not null, primary key
#  name             :string
#  other_languages  :json
#  primary_language :string           default("en"), not null
#  requires_review  :boolean          default(FALSE), not null
#  slug             :string
#  updated_at       :datetime         not null
#

class Catalog < ActiveRecord::Base
  include AvailableLocales

  validates_presence_of :name
  validates_presence_of :primary_language
  validates_presence_of :slug
  validates_uniqueness_of :slug
  validates_inclusion_of :primary_language, :in => :available_locales
  validate :other_languages_included_in_available_locales

  has_many :catalog_permissions, :dependent => :destroy
  has_many :items
  has_many :item_types

  def self.sorted
    order("LOWER(catalogs.name) ASC")
  end

  private

  def other_languages_included_in_available_locales
    return if ((other_languages || []) - available_locales).empty?
    errors.add(
      :other_languages,
      "can only include #{available_locales.join(', ')}"
    )
  end
end
