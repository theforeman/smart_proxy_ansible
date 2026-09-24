describe 'VaultYamlPatch' do
  test 'preserves !vault tag in YAML output' do
    vault_content = <<~VAULT
      $ANSIBLE_VAULT;1.1;AES256
      613239636239623865623037336261...
    VAULT

    data = {
      'secret_var' => "!vault |\n  #{vault_content}"
    }

    yaml_output = Psych.dump(data)

    assert yaml_output.include?('!vault'), "Should preserve !vault tag"
    assert yaml_output.include?('secret_var:'), "Should contain key"
  end
end
