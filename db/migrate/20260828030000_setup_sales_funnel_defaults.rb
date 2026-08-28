# frozen_string_literal: true

class SetupSalesFunnelDefaults < ActiveRecord::Migration[7.0]
  def up
    Account.find_each do |account|
      # 1. Equipo de Ventas
      sales_team = account.teams.find_or_create_by!(name: 'Ventas') do |team|
        team.description = 'Equipo comercial y cierre de ventas'
        team.allow_auto_assign = true
      end

      # 2. Etiquetas del Funnel de Ventas
      funnel_labels = [
        { title: '1_lead_nuevo', color: '#3B82F6', description: 'Prospecto nuevo sin contactar' },
        { title: '2_calificado', color: '#F59E0B', description: 'Prospecto con interés o requisitos validados' },
        { title: '3_cotizado', color: '#8B5CF6', description: 'Cotización, catálogo o precio enviado' },
        { title: '4_negociacion', color: '#F97316', description: 'Resolviendo dudas de pago/entrega/cierre' },
        { title: '5_venta_ganada', color: '#10B981', description: 'Venta cerrada y cobrada con éxito' },
        { title: '6_venta_perdida', color: '#EF4444', description: 'Venta no concretada o descartada' }
      ]

      funnel_labels.each do |label_data|
        label = account.labels.find_or_initialize_by(title: label_data[:title])
        label.color = label_data[:color]
        label.description = label_data[:description]
        label.show_on_sidebar = true
        label.save!
      end

      # 3. Atributos Personalizados de Venta
      custom_attributes = [
        {
          attribute_display_name: 'Monto de Venta',
          attribute_key: 'monto_venta',
          attribute_model: 'conversation_attribute',
          attribute_display_type: 'number',
          attribute_description: 'Valor monetario estimado o cerrado de la venta'
        },
        {
          attribute_display_name: 'Producto de Interés',
          attribute_key: 'producto_interes',
          attribute_model: 'conversation_attribute',
          attribute_display_type: 'text',
          attribute_description: 'Nombre del producto o servicio cotizado'
        },
        {
          attribute_display_name: 'Motivo de Pérdida',
          attribute_key: 'motivo_perdida',
          attribute_model: 'conversation_attribute',
          attribute_display_type: 'list',
          attribute_values: ['Precio elevado', 'Sin stock / disponibilidad', 'Compró a la competencia', 'No volvió a responder', 'No califica'],
          attribute_description: 'Razón por la cual la venta no se concretó'
        }
      ]

      custom_attributes.each do |attr_data|
        cad = account.custom_attribute_definitions.find_or_initialize_by(attribute_key: attr_data[:attribute_key])
        cad.attribute_display_name = attr_data[:attribute_display_name]
        cad.attribute_model = attr_data[:attribute_model]
        cad.attribute_display_type = attr_data[:attribute_display_type]
        cad.attribute_description = attr_data[:attribute_description]
        cad.attribute_values = attr_data[:attribute_values] if attr_data[:attribute_values].present?
        cad.save!
      end

      # 4. Reglas de Automatización
      rule_lead = account.automation_rules.find_or_initialize_by(name: '[Funnel] Asignar Lead Nuevo a Ventas')
      rule_lead.event_name = 'conversation_created'
      rule_lead.description = 'Añade la etiqueta 1_lead_nuevo y asigna automáticamente al equipo Ventas al crearse una conversación'
      rule_lead.active = true
      rule_lead.conditions = [
        {
          'attribute_key' => 'status',
          'filter_operator' => 'equal_to',
          'values' => ['open'],
          'query_operator' => nil
        }
      ]
      rule_lead.actions = [
        { 'action_name' => 'add_label', 'action_params' => ['1_lead_nuevo'] },
        { 'action_name' => 'assign_team', 'action_params' => [sales_team.id] }
      ]
      rule_lead.save!

      rule_intent = account.automation_rules.find_or_initialize_by(name: '[Funnel] Auto-calificar por Intención de Compra')
      rule_intent.event_name = 'message_created'
      rule_intent.description = 'Cambia el estado a 2_calificado cuando el cliente escribe palabras clave de compra'
      rule_intent.active = true
      rule_intent.conditions = [
        {
          'attribute_key' => 'message_type',
          'filter_operator' => 'equal_to',
          'values' => ['incoming'],
          'query_operator' => 'AND'
        },
        {
          'attribute_key' => 'content',
          'filter_operator' => 'contains',
          'values' => ['precio', 'costo', 'cotizar', 'cotizacion', 'comprar', 'catalogo', 'cuanto cuesta', 'pago', 'yape', 'transferencia'],
          'query_operator' => nil
        }
      ]
      rule_intent.actions = [
        { 'action_name' => 'add_label', 'action_params' => ['2_calificado'] }
      ]
      rule_intent.save!
    end
  end

  def down
    # No-op to avoid destructive data loss
  end
end
