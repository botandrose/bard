require "bard/plugin"

Bard::Plugin.register :backup do
  config_method :backup do |value = nil, &block|
    if block
      @backup = Bard::BackupConfig.new(&block)
    elsif value == false
      @backup = Bard::BackupConfig.new { disabled }
    elsif value.nil? # Getter
      @backup ||= Bard::BackupConfig.new { bard }
    else
      raise ArgumentError, "backup accepts false or a block"
    end
  end

  config_method :backup_enabled? do
    backup == true
  end
end
