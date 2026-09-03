# frozen_string_literal: true

class SuperAdmin::ConsumerClaimsController < SuperAdmin::ApplicationController
  def update
    if requested_resource.update(resource_params)
      if requested_resource.saved_change_to_status? && requested_resource.resolved?
        requested_resource.update(resolved_at: Time.current, resolved_by: current_super_admin&.email || 'SuperAdmin')
      end
      redirect_to [namespace, requested_resource], notice: 'Hoja de reclamación actualizada correctamente.'
    else
      render :edit, locals: {
        page: Administrate::Page::Form.new(dashboard, requested_resource)
      }, status: :unprocessable_entity
    end
  end
end
