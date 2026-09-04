# frozen_string_literal: true

namespace :help_center do
  desc 'Seed VoIP, Click-to-call, Tipificaciones y Reportes articles into internal Help Center'
  task seed_voip_articles: :environment do
    docs_dir = Rails.root.join('docs', 'centro_de_ayuda')
    unless Dir.exist?(docs_dir)
      puts "Error: Directorio #{docs_dir} no encontrado."
      exit 1
    end

    categories_config = [
      {
        name: 'Telefonía y Click-to-call',
        slug: 'telefonia-click-to-call',
        description: 'Guías de uso del marcador WebRTC, configuración de micrófono, emisión y cancelación inmediata de llamadas.',
        icon: 'phone',
        articles: [
          { file: '01_primeros_pasos_click_to_call.md', slug: 'primeros-pasos-click-to-call' },
          { file: '02_marcado_y_cancelacion_inmediata_de_llamadas.md', slug: 'marcado-y-cancelacion-inmediata-llamadas' },
          { file: '03_clasificacion_llamadas_efectivas_pruebas_y_no_efectivas.md', slug: 'clasificacion-llamadas-efectivas-pruebas-no-efectivas' }
        ]
      },
      {
        name: 'Tipificación Comercial y Grabaciones',
        slug: 'tipificacion-comercial-grabaciones',
        description: 'Significado de los estados comerciales, sincronización con el chat y escucha de grabaciones de audio.',
        icon: 'check-circle',
        articles: [
          { file: '04_guia_de_tipificacion_llamadas_vs_conversaciones.md', slug: 'guia-tipificacion-llamadas-vs-conversaciones' },
          { file: '05_reproductor_de_audio_y_escucha_de_grabaciones.md', slug: 'reproductor-audio-escucha-grabaciones' }
        ]
      },
      {
        name: 'Reportes y Analítica de Negocio',
        slug: 'reportes-y-analitica-negocio',
        description: 'Monitoreo de workforce de vendedores, efectividad de llamadas, prospección saliente y vueltas de base de datos.',
        icon: 'bar-chart',
        articles: [
          { file: '06_dashboard_click_to_call_y_workforce_de_asesores.md', slug: 'dashboard-click-to-call-workforce-asesores' },
          { file: '07_dashboard_efectividad_base_de_datos_y_reciclaje_vueltas.md', slug: 'dashboard-efectividad-base-datos-reciclaje-vueltas' }
        ]
      }
    ]

    Account.find_each do |account|
      puts "Procesando Cuenta ID: #{account.id} - #{account.name}..."
      admin_user = account.users.first
      next if admin_user.blank?

      # 1. Portal
      portal_slug = "centro-de-ayuda-#{account.id}"
      portal = account.portals.find_or_initialize_by(slug: portal_slug)
      portal.assign_attributes(
        name: 'Centro de Ayuda AIRM',
        header_text: 'Base de conocimiento y manuales internos para el equipo',
        page_title: 'Centro de Ayuda Interno',
        color: '#1f93ff'
      )
      portal.save(validate: false)

      # 2. Categorías y Artículos
      categories_config.each_with_index do |cat_info, cat_idx|
        category = portal.categories.find_or_initialize_by(slug: cat_info[:slug], locale: 'es')
        category.assign_attributes(
          account_id: account.id,
          name: cat_info[:name],
          description: cat_info[:description],
          icon: cat_info[:icon],
          position: cat_idx + 1
        )
        category.save(validate: false)

        cat_info[:articles].each_with_index do |art_info, art_idx|
          file_path = docs_dir.join(art_info[:file])
          next unless File.exist?(file_path)

          raw_text = File.read(file_path)
          title = raw_text[/^#\s+(.+)$/, 1] || art_info[:slug].titleize
          content = raw_text.sub(/^#\s+.+$\n+/, '')

          article_slug = "#{art_info[:slug]}-#{account.id}"
          article = portal.articles.find_or_initialize_by(slug: article_slug)
          article.assign_attributes(
            account_id: account.id,
            category_id: category.id,
            author_id: admin_user.id,
            title: title,
            content: content,
            status: :published,
            locale: 'es',
            position: art_idx + 1
          )
          article.save(validate: false)
          puts "  -> Artículo sincronizado: #{title}"
        end
      end
    end

    puts "\n✅ Todos los artículos del Centro de Ayuda fueron sincronizados exitosamente."
  end
end
