require 'psych'
module VaultYamlPatch
  VAULT_PREFIX = /\A!vault\s*\|\n/

  def visit_String(o)
    if o.match?(VAULT_PREFIX)
      value = o.sub(VAULT_PREFIX, '')
      @emitter.scalar(
        value,
        nil,
        "!vault",
        false,
        false,
        Psych::Nodes::Scalar::LITERAL
      )
    else
      super
    end
  end
end
