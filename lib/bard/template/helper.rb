module Rails
  class TemplateRunner

    def project_name
      @root.split("/").last
    end

    def file_append(file, data)
      log 'file_append', file
      append_file(file, "\n#{data}")
    end

    def file_inject(file_name, sentinel, string, before_after=:after)
      log 'file_inject', file_name
      gsub_file file_name, /(#{Regexp.escape(sentinel)})/mi do |match|
        if :after == before_after
          "#{match}\n#{string}"
        else
          "#{string}\n#{match}"
        end
      end
    end

    def bard_load_template(template_file)
      load_template Gem.required_location "bard", "bard/template/#{template_file}.rb"
    end
  end
end