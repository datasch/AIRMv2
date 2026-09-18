# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
class Api::V1::Accounts::CoverageController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def reports
    account = Current.account
    leads_scope = account.coverage_leads

    # Filtros
    leads_scope = leads_scope.by_departamento(params[:departamento])
    leads_scope = leads_scope.by_ciudad(params[:ciudad])
    leads_scope = leads_scope.by_macro_sector(params[:macro_sector])
    leads_scope = leads_scope.by_agente(params[:agente])

    if params[:estado].present? && params[:estado] != 'ALL'
      leads_scope = case params[:estado]
                    when 'Contactado'
                      leads_scope.where("estado LIKE '%Contactado%' OR estado LIKE '%Prueba enviada%'")
                    when 'Por Contactar'
                      leads_scope.where("estado LIKE '%Por Contactar%'")
                    when 'Enviando'
                      leads_scope.where("estado LIKE '%Enviando%'")
                    when 'Sin WhatsApp / Error'
                      leads_scope.where("estado LIKE '%Sin WhatsApp%' OR estado LIKE '%Error%' OR estado LIKE '%Descarte%'")
                    else
                      leads_scope.where(estado: params[:estado])
                    end
    end

    if params[:start_date].present?
      start_d = begin
        Time.zone.parse(params[:start_date])
      rescue StandardError
        nil
      end
    end
    if params[:end_date].present?
      end_d = begin
        Time.zone.parse(params[:end_date])
      rescue StandardError
        nil
      end
    end
    leads_scope = leads_scope.by_date_range(start_d, end_d) if start_d || end_d

    if params[:search].present?
      q = "%#{params[:search].to_s.downcase.strip}%"
      search_clause = [
        'LOWER(empresa) LIKE :q',
        'LOWER(contacto_sugerido) LIKE :q',
        'LOWER(ubicacion) LIKE :q',
        'LOWER(sector) LIKE :q',
        'LOWER(departamento) LIKE :q',
        'LOWER(ciudad_distrito) LIKE :q',
        'LOWER(agente_nombre) LIKE :q',
        'phone_number LIKE :q'
      ].join(' OR ')
      leads_scope = leads_scope.where(search_clause, q: q)
    end

    total = leads_scope.count
    contactados = leads_scope.where("estado LIKE '%Contactado%' OR estado LIKE '%Prueba enviada%'").count
    pendientes = leads_scope.where("estado LIKE '%Por Contactar%'").count
    enviando = leads_scope.where("estado LIKE '%Enviando%'").count
    sin_whatsapp = leads_scope.where("estado LIKE '%Sin WhatsApp%' OR estado LIKE '%Error%' OR estado LIKE '%Descarte%'").count

    tasa_contacto = total.positive? ? ((contactados.to_f / total) * 100).round(1) : 0

    unique_dptos = leads_scope.reorder(nil).distinct.pluck(:departamento).compact_blank.sort
    unique_distritos = leads_scope.reorder(nil).distinct.pluck(:ciudad_distrito).compact_blank.sort

    # Agrupación por departamentos
    region_counts = leads_scope.reorder(nil).group(:departamento).count
    region_contacted = leads_scope.reorder(nil).where("estado LIKE '%Contactado%' OR estado LIKE '%Prueba enviada%'").group(:departamento).count

    regions_raw = region_counts.map do |reg, cnt|
      cont = region_contacted[reg] || 0
      pct = cnt.positive? ? ((cont.to_f / cnt) * 100).round(0) : 0
      { region: reg.presence || 'Otras Provincias', total: cnt, contactados: cont, pct: pct }
    end
    regions_distribution = regions_raw.sort_by { |r| -r[:total] }

    # Agrupación por macro sector
    sector_counts = leads_scope.reorder(nil).group(:macro_sector).count
    sector_contacted = leads_scope.reorder(nil).where("estado LIKE '%Contactado%' OR estado LIKE '%Prueba enviada%'").group(:macro_sector).count

    sectors_raw = sector_counts.map do |sec, cnt|
      cont = sector_contacted[sec] || 0
      pct = cnt.positive? ? ((cont.to_f / cnt) * 100).round(0) : 0
      macro_info = Coverage::SyncService.clasificar_macro_sector(sec)
      { sector: sec.presence || 'Otros Servicios B2B', total: cnt, contactados: cont, pct: pct, color: macro_info[:color] }
    end
    sectors_distribution = sectors_raw.sort_by { |s| -s[:total] }

    # Evolución temporal (por fecha_envio o fecha_ingreso)
    timeline_raw = leads_scope.reorder(nil).where.not(fecha_envio: nil).group('DATE(fecha_envio)').count
    timeline_raw = leads_scope.reorder(nil).where.not(fecha_ingreso: nil).group('DATE(fecha_ingreso)').count if timeline_raw.empty?

    timeline = timeline_raw.map do |dt, cnt|
      { date: dt.to_s, count: cnt }
    end
    timeline = timeline.sort_by { |t| t[:date] }

    # Métricas por Asesor / Agente
    agent_leads = leads_scope.reorder(nil).where.not(agente_nombre: [nil, '']).group(:agente_nombre).count
    agent_contacted = leads_scope.reorder(nil).where.not(agente_nombre: [nil, ''])
                                 .where("estado LIKE '%Contactado%' OR estado LIKE '%Prueba enviada%'")
                                 .group(:agente_nombre).count
    agent_replied = leads_scope.reorder(nil).where.not(agente_nombre: [nil, ''])
                               .where.not(fecha_respuesta: nil)
                               .group(:agente_nombre).count

    agents_raw = agent_leads.map do |agente_name, total_leads|
      cont = agent_contacted[agente_name] || 0
      repl = agent_replied[agente_name] || 0
      rate = total_leads.positive? ? ((repl.to_f / total_leads) * 100).round(1) : 0
      {
        agente: agente_name,
        leads: total_leads,
        contactados: cont,
        respondidos: repl,
        tasa_respuesta: rate
      }
    end
    agents_metrics = agents_raw.sort_by { |a| -a[:leads] }

    # Opciones de filtros globales
    all_dptos = account.coverage_leads.reorder(nil).distinct.pluck(:departamento).compact_blank.sort
    all_sectors = account.coverage_leads.reorder(nil).distinct.pluck(:macro_sector).compact_blank.sort
    all_agents = account.coverage_leads.reorder(nil).distinct.pluck(:agente_nombre).compact_blank.sort

    # Formateo de los leads para mapa y lista
    leads_list = leads_scope.limit(1000).map do |l|
      macro_info = Coverage::SyncService.clasificar_macro_sector(l.macro_sector || l.sector)
      clean_stat = l.clean_status
      stat_color = l.status_color

      {
        id: l.id,
        datatable_id: l.datatable_id,
        empresa: l.empresa.presence || 'Empresa Sin Nombre',
        sector: l.sector.presence || 'General',
        macro_sector: l.macro_sector.presence || macro_info[:nombre],
        sector_color: macro_info[:color],
        contacto_sugerido: l.contacto_sugerido.presence || 'No especificado',
        ubicacion: l.ubicacion.presence || '',
        departamento: l.departamento.presence || 'Lima',
        ciudad_distrito: l.ciudad_distrito.presence || 'Lima',
        lat: l.lat&.to_f || -12.0520,
        lon: l.lon&.to_f || -77.0380,
        sitio_web: l.sitio_web.presence || '',
        oferta_solucion: l.oferta_solucion.presence || '',
        estado: l.estado.presence || 'Por Contactar',
        estado_clean: clean_stat,
        status_color: stat_color,
        fecha_ingreso: l.fecha_ingreso&.strftime('%Y-%m-%d %H:%M'),
        fecha_envio: l.fecha_envio&.strftime('%Y-%m-%d %H:%M'),
        fecha_dia: (l.fecha_envio || l.fecha_ingreso)&.strftime('%Y-%m-%d'),
        agente: l.agente_nombre.presence || 'Sin Asignar',
        contact_id: l.contact_id,
        conversation_id: l.conversation_id,
        tiempo_operativo: l.tiempo_operativo.presence || '',
        alerta_tiempo: l.alerta_tiempo.presence || ''
      }
    end

    last_synced = account.coverage_leads.maximum(:synced_at) || account.coverage_leads.maximum(:updated_at)

    render json: {
      summary: {
        total: total,
        contactados: contactados,
        pendientes: pendientes,
        enviando: enviando,
        sin_whatsapp: sin_whatsapp,
        tasa_contacto: tasa_contacto,
        total_departamentos: unique_dptos.size,
        total_ciudades: unique_distritos.size,
        last_synced_at: last_synced&.strftime('%d/%m/%Y %H:%M:%S')
      },
      regions_distribution: regions_distribution,
      sectors_distribution: sectors_distribution,
      timeline: timeline,
      agents_metrics: agents_metrics,
      filter_options: {
        regions: all_dptos,
        sectors: all_sectors,
        agents: all_agents
      },
      leads: leads_list
    }
  rescue StandardError => e
    Rails.logger.error "[CoverageController#reports] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { error: e.message }, status: :internal_server_error
  end

  def sync
    account = Current.account
    service = Coverage::SyncService.new(account: account)

    if params[:rows].is_a?(Array) && params[:rows].any?
      synced = service.process_rows(params[:rows])
      render json: { ok: true, synced_count: synced, total: account.coverage_leads.count }
    else
      result = service.sync_from_datatable!
      render json: result
    end
  rescue StandardError => e
    Rails.logger.error "[CoverageController#sync] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def sync_status
    account = Current.account
    last_synced = account.coverage_leads.maximum(:synced_at) || account.coverage_leads.maximum(:updated_at)
    render json: {
      total_leads: account.coverage_leads.count,
      last_synced_at: last_synced&.strftime('%d/%m/%Y %H:%M:%S'),
      matched_contacts: account.coverage_leads.where.not(contact_id: nil).count,
      matched_agents: account.coverage_leads.where.not(agente_nombre: [nil, '']).count
    }
  end

  private

  def check_authorization
    head :forbidden unless Current.account_user&.administrator? || Current.account_user&.agent?
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
