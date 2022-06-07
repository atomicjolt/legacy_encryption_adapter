require "legacy_encryption_adapter/version"

module LegacyEncryptionAdapter

  def self.extended(base) # :nodoc:
    base.class_eval do
      include InstanceMethods
    end
  end

  module InstanceMethods

    def legacy_encryption_adapter_attr_encrypted_decrypt(property_name)
      legacy_prop_name = "#{property_name}_2".to_sym
      legacy_encrypted_field_name = "encrypted_#{legacy_prop_name}".to_sym
      legacy_encrypted_field = send(legacy_encrypted_field_name)
      attr_encrypted_decrypt(legacy_prop_name, legacy_encrypted_field)  
    end

    def legacy_encryption_adapter_attr_encrypted_encrypt(property_name, legacy_encrypted_field)
      legacy_prop_name = "#{property_name}_2".to_sym
      legacy_encrypted_field_name = "encrypted_#{legacy_prop_name}".to_sym
      encrypted_value = attr_encrypted_encrypt(legacy_prop_name, legacy_encrypted_field)
      send("#{legacy_encrypted_field_name}=", encrypted_value)
    end

    def legacy_encryption_adapter_get_impl(property_name, use_legacy_method, non_legacy_behavior, use_legacy_override)
      should_use_legacy = if respond_to? use_legacy_method
                            send(use_legacy_method)
                          else
                            true
                          end

      has_override = !use_legacy_override.nil?                  
      if has_override
        if use_legacy_override
          legacy_encryption_adapter_attr_encrypted_decrypt(property_name)
        else
          non_legacy_behavior.call
        end
      else
        if should_use_legacy == true 
          legacy_encryption_adapter_attr_encrypted_decrypt(property_name)
        else
          non_legacy_behavior.call
        end
      end
    end

    def legacy_encryption_adapter_set_impl(property_name, property_value,use_legacy_method, non_legacy_behavior)
      should_use_legacy = if respond_to? use_legacy_method
                            send(use_legacy_method)
                          else
                            true
                          end

      # When we write set both rails 7 encrypted field and legacy field
      if should_use_legacy == true 
        legacy_encryption_adapter_attr_encrypted_encrypt(property_name, property_value)
      end
      non_legacy_behavior.call
    end
  end

  def legacy_encryption_adapter_attributes
    @legacy_encryption_adapter_attributes ||= []
  end

  def legacy_encryption_adapter(property_name, use_legacy)
    legacy_encryption_adapter_attributes << property_name

    define_method(property_name.to_sym) do |*args|
      legacy_encryption_override = if args[0]&.is_a?(Hash)
                                     args[0][:legacy_encryption_adapter_use_legacy_encryption] 
                                   else
                                     nil
                                   end

      send(:legacy_encryption_adapter_get_impl, property_name, use_legacy, Proc.new { super() }, legacy_encryption_override)
    end

    define_method("#{property_name.to_sym}=") do |*args|
      send(:legacy_encryption_adapter_set_impl, property_name, args[0], use_legacy, Proc.new { super(*args) })
    end

    define_method("legacy_encryption_adapter_diff_#{property_name}") do |*_args|
      legacy = send(property_name, { legacy_encryption_adapter_use_legacy_encryption: true })
      current = send(property_name, { legacy_encryption_adapter_use_legacy_encryption: false })
      [legacy, current]
    end
  end
end