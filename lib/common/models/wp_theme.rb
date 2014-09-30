# encoding: UTF-8

require 'wp_theme/findable'
require 'wp_theme/versionable'
require 'wp_theme/vulnerable'
require 'wp_theme/info'
require 'wp_theme/output'
require 'wp_theme/childtheme'

class WpTheme < WpItem
  extend WpTheme::Findable
  include WpTheme::Versionable
  include WpTheme::Vulnerable
  include WpTheme::Info
  include WpTheme::Output
  include WpTheme::Childtheme

  attr_accessor :referenced_url

  def allowed_options; super << :referenced_url end

  # Sets the @uri
  #
  # @param [ URI ] target_base_uri The URI of the wordpress blog
  #
  # @return [ void ]
  def forge_uri(target_base_uri)
    @uri = target_base_uri.merge(URI.encode(wp_content_dir + '/themes/' + name + '/'))
  end

  # @return [ String ] The url to the theme stylesheet
  def style_url
    @uri.merge('style.css').to_s
  end

end
