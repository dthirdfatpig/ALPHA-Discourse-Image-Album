# frozen_string_literal: true

require "tempfile"

module ::DiscourseImageAlbum
  class ZipExporter
    def self.export(album)
      new(album).generate
    end

    attr_reader :album

    def initialize(album)
      @album = album
    end

    def generate
      begin
        require "zip"
      rescue LoadError
        Rails.logger.warn("[DiscourseImageAlbum] rubyzip gem not available")
        return nil
      end

      temp_zip = Tempfile.new(["album-#{album.id}-", ".zip"], binmode: true)

      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zipfile|
        index = 1
        album.items.includes(:upload).find_each do |item|
          filename = sanitized_filename(item, index)
          data = extract_image_bytes(item)

          if data.present?
            zipfile.get_output_stream(filename) { |os| os.write(data) }
            index += 1
          end
        end
      end

      temp_zip
    rescue => e
      Rails.logger.error("[DiscourseImageAlbum] Error generating zip for album #{album.id}: #{e.message}")
      temp_zip&.close!
      nil
    end

    private

    def sanitized_filename(item, index)
      base = item.title.presence || item.original_filename.presence || "photo_#{index}"
      cleaned = base.gsub(/[^0-9A-Za-z.\-_]/, "_").squeeze("_")
      
      ext = File.extname(cleaned)
      if ext.blank?
        ext = item.upload&.extension.presence || ".jpg"
        ext = ".#{ext}" unless ext.start_with?(".")
        cleaned += ext
      end

      "#{index.to_s.rjust(4, '0')}_#{cleaned}"
    end

    def extract_image_bytes(item)
      if item.upload.present?
        upload = item.upload
        if Discourse.store.has_been_uploaded?(upload.url)
          if Discourse.store.external?
            # Fetch from S3/remote storage
            begin
              file = Discourse.store.download(upload)
              return file.read if file
            rescue => e
              Rails.logger.warn("[DiscourseImageAlbum] Remote upload download failed: #{e.message}")
            end
          else
            # Local storage
            local_path = Discourse.store.path_for(upload)
            return File.binread(local_path) if local_path && File.exist?(local_path)
          end
        end
      end

      # Fallback to direct URL if image_url is present
      url = item.image_url.presence || item.upload&.url
      if url.present?
        full_url = UrlHelper.absolute(url)
        begin
          response = FinalDestination::HTTP.get(URI.parse(full_url))
          return response.body if response.is_a?(Net::HTTPSuccess)
        rescue => e
          Rails.logger.warn("[DiscourseImageAlbum] URL download failed for #{full_url}: #{e.message}")
        end
      end

      nil
    end
  end
end
