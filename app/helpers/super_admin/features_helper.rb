module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    "Tiene activo el plan <span class='font-semibold text-emerald-600 uppercase'>Enterprise</span> con todas las características desbloqueadas de forma ilimitada."
  end
end
