# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Metrics/BlockLength
class Coverage::SyncService
  DEFAULT_N8N_URL = 'https://flujo.giantucchi.com/api/v1/data-tables/VesQdjpK6d2SrIjJ/rows'
  # rubocop:disable Layout/LineLength
  DEFAULT_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI3ZTVjMjc2OC05YWVhLTRhZTQtODliNy1kOWYwYWJiZTdiOGYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiZjM1NzRlNzUtMzhiZC00MDE3LTlkYmEtZjQ0N2IyZWY5ZjNiIiwiaWF0IjoxNzg2MDU0NDI4fQ.EinI5hjG7Mk82gwobmPlRyR0BTbTmT9d8tIRGFvGxQI'
  # rubocop:enable Layout/LineLength

  GEO_DB = [
    # Arequipa
    { key: 'yanahuara', lat: -16.3880, lon: -71.5420, ciudad: 'Yanahuara', dpto: 'Arequipa' },
    { key: 'cayma', lat: -16.3750, lon: -71.5500, ciudad: 'Cayma', dpto: 'Arequipa' },
    { key: 'bustamante y rivero', lat: -16.4250, lon: -71.5250, ciudad: 'Bustamante y Rivero', dpto: 'Arequipa' },
    { key: 'cerro colorado', lat: -16.3600, lon: -71.5650, ciudad: 'Cerro Colorado', dpto: 'Arequipa' },
    { key: 'selva alegre', lat: -16.3800, lon: -71.5200, ciudad: 'Selva Alegre', dpto: 'Arequipa' },
    { key: 'arequipa', lat: -16.3988, lon: -71.5369, ciudad: 'Arequipa', dpto: 'Arequipa' },

    # La Libertad / Trujillo
    { key: 'víctor larco', lat: -8.1350, lon: -79.0450, ciudad: 'Víctor Larco', dpto: 'La Libertad' },
    { key: 'victor larco', lat: -8.1350, lon: -79.0450, ciudad: 'Víctor Larco', dpto: 'La Libertad' },
    { key: 'el golf', lat: -8.1380, lon: -79.0420, ciudad: 'El Golf (Trujillo)', dpto: 'La Libertad' },
    { key: 'huanchaco', lat: -8.0800, lon: -79.1200, ciudad: 'Huanchaco', dpto: 'La Libertad' },
    { key: 'trujillo', lat: -8.1116, lon: -79.0287, ciudad: 'Trujillo', dpto: 'La Libertad' },
    { key: 'la libertad', lat: -8.1116, lon: -79.0287, ciudad: 'Trujillo', dpto: 'La Libertad' },

    # Cusco
    { key: 'urubamba', lat: -13.3050, lon: -72.1150, ciudad: 'Urubamba', dpto: 'Cusco' },
    { key: 'san blas', lat: -13.5150, lon: -71.9750, ciudad: 'San Blas (Cusco)', dpto: 'Cusco' },
    { key: 'cusco', lat: -13.5319, lon: -71.9675, ciudad: 'Cusco', dpto: 'Cusco' },
    { key: 'cuzco', lat: -13.5319, lon: -71.9675, ciudad: 'Cusco', dpto: 'Cusco' },

    # Piura
    { key: 'sullana', lat: -4.9039, lon: -80.6853, ciudad: 'Sullana', dpto: 'Piura' },
    { key: 'talara', lat: -4.5772, lon: -81.2719, ciudad: 'Talara', dpto: 'Piura' },
    { key: 'piura', lat: -5.1945, lon: -80.6328, ciudad: 'Piura', dpto: 'Piura' },

    # Lambayeque / Chiclayo
    { key: 'pimentel', lat: -6.8360, lon: -79.9340, ciudad: 'Pimentel', dpto: 'Lambayeque' },
    { key: 'lambayeque', lat: -6.7000, lon: -79.9000, ciudad: 'Lambayeque', dpto: 'Lambayeque' },
    { key: 'chiclayo', lat: -6.7714, lon: -79.8409, ciudad: 'Chiclayo', dpto: 'Lambayeque' },

    # Junín / Huancayo
    { key: 'el tambo', lat: -12.0450, lon: -75.2200, ciudad: 'El Tambo', dpto: 'Junín' },
    { key: 'chilca', lat: -12.0800, lon: -75.2000, ciudad: 'Chilca', dpto: 'Junín' },
    { key: 'huancayo', lat: -12.0651, lon: -75.2049, ciudad: 'Huancayo', dpto: 'Junín' },
    { key: 'junín', lat: -12.0651, lon: -75.2049, ciudad: 'Huancayo', dpto: 'Junín' },
    { key: 'junin', lat: -12.0651, lon: -75.2049, ciudad: 'Huancayo', dpto: 'Junín' },

    # Ica
    { key: 'la tinguiña', lat: -14.0450, lon: -75.7100, ciudad: 'La Tinguiña', dpto: 'Ica' },
    { key: 'paracas', lat: -13.8400, lon: -76.2500, ciudad: 'Paracas', dpto: 'Ica' },
    { key: 'chincha', lat: -13.4178, lon: -76.1328, ciudad: 'Chincha', dpto: 'Ica' },
    { key: 'pisco', lat: -13.7103, lon: -76.2042, ciudad: 'Pisco', dpto: 'Ica' },
    { key: 'ica', lat: -14.0678, lon: -75.7286, ciudad: 'Ica', dpto: 'Ica' },

    # Tacna
    { key: 'tacna', lat: -18.0139, lon: -70.2525, ciudad: 'Tacna', dpto: 'Tacna' },

    # Áncash
    { key: 'nuevo chimbote', lat: -9.1250, lon: -78.5300, ciudad: 'Nuevo Chimbote', dpto: 'Áncash' },
    { key: 'chimbote', lat: -9.0745, lon: -78.5936, ciudad: 'Chimbote', dpto: 'Áncash' },
    { key: 'huaraz', lat: -9.5261, lon: -77.5288, ciudad: 'Huaraz', dpto: 'Áncash' },
    { key: 'áncash', lat: -9.0745, lon: -78.5936, ciudad: 'Chimbote', dpto: 'Áncash' },
    { key: 'ancash', lat: -9.0745, lon: -78.5936, ciudad: 'Chimbote', dpto: 'Áncash' },

    # San Martín
    { key: 'tarapoto', lat: -6.4850, lon: -76.3630, ciudad: 'Tarapoto', dpto: 'San Martín' },
    { key: 'moyobamba', lat: -6.0333, lon: -76.9667, ciudad: 'Moyobamba', dpto: 'San Martín' },
    { key: 'san martín', lat: -6.4850, lon: -76.3630, ciudad: 'Tarapoto', dpto: 'San Martín' },
    { key: 'san martin', lat: -6.4850, lon: -76.3630, ciudad: 'Tarapoto', dpto: 'San Martín' },

    # Cajamarca
    { key: 'baños del inca', lat: -7.1650, lon: -78.4650, ciudad: 'Baños del Inca', dpto: 'Cajamarca' },
    { key: 'jaén', lat: -5.7083, lon: -78.8083, ciudad: 'Jaén', dpto: 'Cajamarca' },
    { key: 'cajamarca', lat: -7.1638, lon: -78.5128, ciudad: 'Cajamarca', dpto: 'Cajamarca' },

    # Ucayali
    { key: 'pucallpa', lat: -8.3791, lon: -74.5539, ciudad: 'Pucallpa', dpto: 'Ucayali' },
    { key: 'ucayali', lat: -8.3791, lon: -74.5539, ciudad: 'Pucallpa', dpto: 'Ucayali' },

    # Loreto
    { key: 'iquitos', lat: -3.7437, lon: -73.2516, ciudad: 'Iquitos', dpto: 'Loreto' },
    { key: 'loreto', lat: -3.7437, lon: -73.2516, ciudad: 'Iquitos', dpto: 'Loreto' },

    # Puno
    { key: 'juliaca', lat: -15.4988, lon: -70.1333, ciudad: 'Juliaca', dpto: 'Puno' },
    { key: 'puno', lat: -15.8402, lon: -70.0219, ciudad: 'Puno', dpto: 'Puno' },

    # Moquegua
    { key: 'ilo', lat: -17.6394, lon: -71.3375, ciudad: 'Ilo', dpto: 'Moquegua' },
    { key: 'moquegua', lat: -17.1950, lon: -70.9357, ciudad: 'Moquegua', dpto: 'Moquegua' },

    # Huánuco
    { key: 'tingo maría', lat: -9.2950, lon: -75.9967, ciudad: 'Tingo María', dpto: 'Huánuco' },
    { key: 'huánuco', lat: -9.9306, lon: -76.2422, ciudad: 'Huánuco', dpto: 'Huánuco' },
    { key: 'huanuco', lat: -9.9306, lon: -76.2422, ciudad: 'Huánuco', dpto: 'Huánuco' },

    # Tumbes
    { key: 'punta sal', lat: -3.9850, lon: -80.9850, ciudad: 'Punta Sal', dpto: 'Tumbes' },
    { key: 'tumbes', lat: -3.5669, lon: -80.4515, ciudad: 'Tumbes', dpto: 'Tumbes' },

    # Ayacucho
    { key: 'ayacucho', lat: -13.1588, lon: -74.2239, ciudad: 'Ayacucho', dpto: 'Ayacucho' },
    { key: 'huamanga', lat: -13.1588, lon: -74.2239, ciudad: 'Ayacucho', dpto: 'Ayacucho' },

    # Madre de Dios
    { key: 'puerto maldonado', lat: -12.5933, lon: -69.1891, ciudad: 'Puerto Maldonado', dpto: 'Madre de Dios' },

    # Amazonas
    { key: 'chachapoyas', lat: -6.2300, lon: -77.8700, ciudad: 'Chachapoyas', dpto: 'Amazonas' },

    # Callao
    { key: 'callao', lat: -12.0550, lon: -77.1150, ciudad: 'Callao', dpto: 'Callao' },

    # Lima Distritos
    { key: 'san isidro', lat: -12.0970, lon: -77.0340, ciudad: 'San Isidro', dpto: 'Lima' },
    { key: 'miraflores', lat: -12.1215, lon: -77.0300, ciudad: 'Miraflores', dpto: 'Lima' },
    { key: 'lince', lat: -12.0830, lon: -77.0340, ciudad: 'Lince', dpto: 'Lima' },
    { key: 'la victoria', lat: -12.0720, lon: -77.0210, ciudad: 'La Victoria', dpto: 'Lima' },
    { key: 'surco', lat: -12.1300, lon: -76.9850, ciudad: 'Santiago de Surco', dpto: 'Lima' },
    { key: 'santiago de surco', lat: -12.1300, lon: -76.9850, ciudad: 'Santiago de Surco', dpto: 'Lima' },
    { key: 'surquillo', lat: -12.1120, lon: -77.0210, ciudad: 'Surquillo', dpto: 'Lima' },
    { key: 'barranco', lat: -12.1480, lon: -77.0210, ciudad: 'Barranco', dpto: 'Lima' },
    { key: 'jesús maría', lat: -12.0750, lon: -77.0460, ciudad: 'Jesús María', dpto: 'Lima' },
    { key: 'jesus maria', lat: -12.0750, lon: -77.0460, ciudad: 'Jesús María', dpto: 'Lima' },
    { key: 'san borja', lat: -12.0980, lon: -77.0050, ciudad: 'San Borja', dpto: 'Lima' },
    { key: 'san miguel', lat: -12.0780, lon: -77.0850, ciudad: 'San Miguel', dpto: 'Lima' },
    { key: 'ate', lat: -12.0480, lon: -76.9250, ciudad: 'Ate', dpto: 'Lima' },
    { key: 'magdalena', lat: -12.0920, lon: -77.0670, ciudad: 'Magdalena del Mar', dpto: 'Lima' },
    { key: 'los olivos', lat: -11.9950, lon: -77.0700, ciudad: 'Los Olivos', dpto: 'Lima' },
    { key: 'pueblo libre', lat: -12.0780, lon: -77.0620, ciudad: 'Pueblo Libre', dpto: 'Lima' },
    { key: 'breña', lat: -12.0600, lon: -77.0500, ciudad: 'Breña', dpto: 'Lima' },
    { key: 'la molina', lat: -12.0850, lon: -76.9450, ciudad: 'La Molina', dpto: 'Lima' },
    { key: 'sjm', lat: -12.1600, lon: -76.9700, ciudad: 'San Juan de Miraflores', dpto: 'Lima' },
    { key: 'sjl', lat: -12.0000, lon: -77.0000, ciudad: 'San Juan de Lurigancho', dpto: 'Lima' },
    { key: 'villa el salvador', lat: -12.2100, lon: -76.9300, ciudad: 'Villa El Salvador', dpto: 'Lima' },
    { key: 'comas', lat: -11.9300, lon: -77.0500, ciudad: 'Comas', dpto: 'Lima' },
    { key: 'lurigancho', lat: -11.9400, lon: -76.7000, ciudad: 'Lurigancho', dpto: 'Lima' },
    { key: 'lurin', lat: -12.2700, lon: -76.8700, ciudad: 'Lurín', dpto: 'Lima' },
    { key: 'lurín', lat: -12.2700, lon: -76.8700, ciudad: 'Lurín', dpto: 'Lima' },
    { key: 'cercado', lat: -12.0500, lon: -77.0350, ciudad: 'Cercado de Lima', dpto: 'Lima' },
    { key: 'lima', lat: -12.0520, lon: -77.0380, ciudad: 'Cercado de Lima', dpto: 'Lima' }
  ].freeze

  def initialize(account:)
    @account = account
  end

  def sync_from_datatable!(api_key: DEFAULT_API_KEY, base_url: DEFAULT_N8N_URL, max_records: 10_000)
    synced_count = 0
    next_cursor = nil

    loop do
      uri = URI("#{base_url}?limit=250#{next_cursor ? "&cursor=#{next_cursor}" : ''}")
      req = Net::HTTP::Get.new(uri)
      req['X-N8N-API-KEY'] = api_key
      req['Accept'] = 'application/json'

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 10) do |http|
        http.request(req)
      end

      unless res.is_a?(Net::HTTPSuccess)
        Rails.logger.warn "[Coverage::SyncService] Respuesta no exitosa de n8n: HTTP #{res.code} - #{res.message}"
        return {
          ok: false,
          error: "Error al conectar con n8n (HTTP #{res.code}). Revisa el certificado SSL o conectividad de #{uri.host}.",
          synced_count: synced_count,
          total_in_db: @account.coverage_leads.count
        }
      end

      data = JSON.parse(res.body)
      rows = data['data'] || []
      break if rows.empty?

      batch_synced = process_rows(rows)
      synced_count += batch_synced

      next_cursor = data['nextCursor']
      break if next_cursor.blank? || synced_count >= max_records
    end

    Rails.logger.info "[Coverage::SyncService] Sincronización finalizada. #{synced_count} registros procesados para cuenta #{@account.id}."
    { ok: true, synced_count: synced_count, total_in_db: @account.coverage_leads.count }
  rescue StandardError => e
    Rails.logger.error "[Coverage::SyncService] Error en sync_from_datatable: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    { ok: false, error: e.message, total_in_db: @account.coverage_leads.count }
  end

  def process_rows(rows)
    processed = 0
    now = Time.current

    rows.each do |row|
      dt_id = row['id'] || row['fila_id']
      raw_tel = row['telefono'] || row['Telefono'] || ''
      clean_tel = raw_tel.to_s.gsub(/\D/, '')

      empresa = (row['empresa'] || row['Empresa'] || '').to_s.strip
      next if clean_tel.blank? && empresa.blank?

      # Idempotencia: buscar lead existente por datatable_id
      lead = @account.coverage_leads.find_or_initialize_by(datatable_id: dt_id) if dt_id.present?
      lead ||= @account.coverage_leads.find_or_initialize_by(phone_number: clean_tel) if clean_tel.present?
      lead ||= @account.coverage_leads.new

      sector_str = (row['sector'] || row['Sector'] || '').to_s.strip
      ubicacion_str = (row['ubicacion'] || row['Ubicacion'] || '').to_s.strip

      # Clasificación exacta de macro sector y georreferenciación
      macro_info = self.class.clasificar_macro_sector(sector_str)

      explicit_lat = row['__lat'] || row['lat'] || row['Lat'] || row['latitude'] || row['Latitude']
      explicit_lon = row['__lon'] || row['lon'] || row['Lon'] || row['longitude'] || row['Longitude']

      geo_info = if explicit_lat.present? && explicit_lon.present? && explicit_lat.to_f != 0.0
                   parsed = self.class.georreferenciar_peru(ubicacion_str, (dt_id || 1).to_i)
                   {
                     lat: explicit_lat.to_f.round(6),
                     lon: explicit_lon.to_f.round(6),
                     ciudad_distrito: parsed[:ciudad_distrito],
                     departamento: parsed[:departamento]
                   }
                 else
                   self.class.georreferenciar_peru(ubicacion_str, (dt_id || 1).to_i)
                 end

      lead.empresa = empresa if empresa.present?
      lead.phone_number = clean_tel
      lead.sector = sector_str
      lead.macro_sector = macro_info[:nombre]
      lead.contacto_sugerido = (row['contacto_sugerido'] || row['Contacto_Sugerido'] || '').to_s.strip
      lead.ubicacion = ubicacion_str
      lead.sitio_web = (row['sitio_web'] || row['Sitio_Web'] || '').to_s.strip
      lead.oferta_solucion = (row['oferta_solucion'] || row['Oferta_Solucion'] || '').to_s.strip
      lead.mensaje_whatsapp = (row['mensaje_whatsapp'] || row['Mensaje_WhatsApp'] || '').to_s.strip
      lead.estado = (row['estado'] || row['Estado'] || 'Por Contactar').to_s.strip
      lead.tiempo_operativo = (row['tiempo_operativo'] || row['Tiempo_Operativo'] || '').to_s.strip
      lead.alerta_tiempo = (row['alerta_tiempo'] || row['Alerta_Tiempo'] || '').to_s.strip
      lead.etiqueta = (row['etiqueta'] || row['Etiqueta'] || '').to_s.strip
      lead.monto_venta = (row['monto_venta'] || row['Monto_Venta'] || '').to_s.strip
      lead.producto_interes = (row['producto_interes'] || row['Producto_Interes'] || '').to_s.strip
      lead.motivo_perdida = (row['motivo_perdida'] || row['Motivo_Perdida'] || '').to_s.strip
      lead.interaccion_log = (row['interaccion_log'] || row['Interaccion_Log'] || '').to_s.strip
      lead.departamento = geo_info[:departamento]
      lead.ciudad_distrito = geo_info[:ciudad_distrito]
      lead.lat = geo_info[:lat]
      lead.lon = geo_info[:lon]
      lead.raw_data = row
      lead.synced_at = now

      # Fechas
      lead.fecha_ingreso = parse_datetime(row['fecha_ingreso'] || row['Fecha_Ingreso'])
      lead.fecha_envio = parse_datetime(row['fecha_envio'] || row['Fecha_Envio'])
      lead.fecha_asignacion = parse_datetime(row['fecha_asignacion'] || row['Fecha_Asignacion'])
      lead.fecha_respuesta = parse_datetime(row['fecha_respuesta'] || row['Fecha_Respuesta'])

      # Agente por defecto desde la fila
      lead.agente_nombre = (row['agente'] || row['Agente'] || '').to_s.strip

      # Match inteligente con registros en AIRM y creación de contactos reales
      match_airm_contact_and_advisor!(lead, clean_tel, empresa, sector_str, macro_info[:nombre], ubicacion_str, geo_info)

      lead.save!
      ::CoverageListener.instance.broadcast_lead_update(@account, lead) if processed < 100
      processed += 1
    end

    processed
  end

  def match_airm_contact_and_advisor!(lead, clean_tel, empresa, sector_str, macro_nombre, ubicacion_str, geo_info)
    return if clean_tel.blank? && empresa.blank?

    last_9 = clean_tel.length >= 9 ? clean_tel[-9..] : clean_tel

    e164_phone = if clean_tel.length >= 7 && !clean_tel.start_with?('51')
                   "+51#{clean_tel}"
                 elsif clean_tel.present?
                   "+#{clean_tel}"
                 end

    # Buscar contacto existente por últimos 9 dígitos o teléfono E.164
    contact = @account.contacts.where('phone_number LIKE ?', "%#{last_9}").first if last_9.present?
    contact ||= @account.contacts.find_by(phone_number: e164_phone) if e164_phone.present?

    # Si no existe, crear el contacto en AIRM
    if contact.blank?
      contact_name = empresa.presence || lead.contacto_sugerido.presence || (e164_phone.present? ? "Lead #{e164_phone}" : 'Lead Comercial')
      valid_phone = e164_phone if e164_phone.present? && e164_phone.match?(/\A\+[1-9]\d{1,14}\z/)

      contact = @account.contacts.new(
        name: contact_name,
        phone_number: valid_phone
      )
    elsif (contact.name.blank? || contact.name.start_with?('Lead ') || contact.name.start_with?('Contacto ')) && empresa.present?
      contact.name = empresa
    end

    # Atributos personalizados enriquecidos en AIRM (trazabilidad centralizada)
    attrs = (contact.custom_attributes || {}).dup
    attrs['cobertura_empresa'] = empresa if empresa.present?
    attrs['cobertura_sector'] = sector_str if sector_str.present?
    attrs['cobertura_macro_sector'] = macro_nombre if macro_nombre.present?
    attrs['cobertura_ubicacion'] = ubicacion_str if ubicacion_str.present?
    attrs['cobertura_departamento'] = geo_info[:departamento] if geo_info[:departamento].present?
    attrs['cobertura_ciudad'] = geo_info[:ciudad_distrito] if geo_info[:ciudad_distrito].present?
    attrs['cobertura_lat'] = geo_info[:lat] if geo_info[:lat].present?
    attrs['cobertura_lon'] = geo_info[:lon] if geo_info[:lon].present?
    attrs['cobertura_oferta_solucion'] = lead.oferta_solucion if lead.oferta_solucion.present?
    attrs['cobertura_datatable_id'] = lead.datatable_id if lead.datatable_id.present?
    attrs['cobertura_synced_at'] = Time.current.iso8601
    contact.custom_attributes = attrs

    contact.save(validate: false) if contact.changed? || contact.new_record?

    lead.contact = contact if contact.persisted?

    # Asegurar contact_inbox con la bandeja por defecto para permitir chats
    default_inbox = @account.inboxes.first
    if default_inbox.present? && contact.persisted?
      @account.contact_inboxes.find_or_create_by(contact_id: contact.id, inbox_id: default_inbox.id) do |ci|
        ci.source_id = contact.phone_number.presence || contact.id.to_s
      end
    end

    # Vincular conversación más reciente y su asesor (assignee)
    if contact.persisted?
      conversation = @account.conversations.where(contact_id: contact.id).order(created_at: :desc).first
      if conversation.present?
        lead.conversation = conversation
        if conversation.assignee.present?
          lead.user = conversation.assignee
          lead.agente_nombre = conversation.assignee.available_name || conversation.assignee.name
        end

        # Calcular primer tiempo de respuesta
        first_reply = conversation.messages.where(message_type: :outgoing).where('created_at > ?', conversation.created_at).order(:created_at).first
        if first_reply.present?
          lead.fecha_respuesta ||= first_reply.created_at
          diff_mins = [((first_reply.created_at - conversation.created_at) / 60).round, 0].max
          lead.tiempo_operativo = "#{diff_mins}m" if lead.tiempo_operativo.blank?
        end
      end
    end
  rescue StandardError => e
    Rails.logger.warn "[Coverage::SyncService] Error matching contact #{clean_tel}: #{e.message}"
  end

  def self.clasificar_macro_sector(sector)
    s = sector.to_s.downcase
    if s.match?(/dental|odonto|estétic|estetic|médic|medica|cirug|spa|salud|derm|clínic|clinic/)
      { nombre: 'Salud, Dental y Estética', color: '#e74c3c' }
    elsif s.match?(/inmobilia|construc|arquitect|obra|acabados/)
      { nombre: 'Inmobiliario y Construcción', color: '#2980b9' }
    elsif s.match?(/software|ti|tic|cloud|erp|crm|saas|app|desarrollo web|tecnolog/)
      { nombre: 'Tecnología y Software', color: '#8e44ad' }
    elsif s.match?(/courier|logístic|logistic|envío|envio|aduan|carga|transporte|milla|casillero/)
      { nombre: 'Logística y Courier', color: '#e67e22' }
    elsif s.match?(/automotriz|taller|mecánic|mecanic|auto|vehícul|motor/)
      { nombre: 'Automotriz y Talleres', color: '#d35400' }
    elsif s.match?(/capacita|institut|diplomad|educa|academia|escuela|formación|curso/)
      { nombre: 'Educación y Capacitación', color: '#27ae60' }
    elsif s.match?(/marketing|publicidad|seo|digital|performance|branding|creativ/)
      { nombre: 'Marketing y Publicidad', color: '#f39c12' }
    elsif s.match?(/abogad|jurídic|juridic|legal|tributar|contab|auditor|marca|notar|leyes/)
      { nombre: 'Legal, Contable y Consultoría', color: '#16a085' }
    elsif s.match?(/vet|pet|animal|grooming|mascot/)
      { nombre: 'Veterinaria y Mascotas', color: '#1abc9c' }
    elsif s.match?(/seguridad|vigilanc|riesgo|resguardo/)
      { nombre: 'Seguridad Privada', color: '#34495e' }
    elsif s.match?(/viaje|turism|hotel|gastronom|restauran|event/)
      { nombre: 'Turismo y Gastronomía', color: '#9b59b6' }
    else
      { nombre: 'Otros Servicios B2B', color: '#7f8c8d' }
    end
  end

  def self.georreferenciar_peru(ubicacion, id = 1)
    u = ubicacion.to_s.downcase
    matched = GEO_DB.find { |entry| u.include?(entry[:key]) }
    matched ||= { lat: -12.0520, lon: -77.0380, ciudad: 'Lima / Provincias', dpto: 'Lima' }

    # Jitter pseudo-aleatorio determinista para separar puntos en el mismo distrito
    pseudo_rand_lat = (((Math.sin(id * 12.9898) * 43_758.5453) % 1) - 0.5) * 0.007
    pseudo_rand_lon = (((Math.cos(id * 78.233) * 43_758.5453) % 1) - 0.5) * 0.007

    final_lat = (matched[:lat] + pseudo_rand_lat).round(6)
    final_lon = (matched[:lon] + pseudo_rand_lon).round(6)

    {
      lat: final_lat,
      lon: final_lon,
      ciudad_distrito: matched[:ciudad],
      departamento: matched[:dpto]
    }
  end

  private

  def parse_datetime(val)
    return nil if val.blank?
    return val if val.is_a?(Time) || val.is_a?(DateTime)

    Time.zone.parse(val.to_s)
  rescue StandardError
    nil
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Metrics/BlockLength
