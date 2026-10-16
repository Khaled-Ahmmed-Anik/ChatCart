module PhotoTestStubs
  def with_photo_stub(target, method_name, replacement)
    original = target.method(method_name)
    target.define_singleton_method(method_name) do |*args, **kwargs, &block|
      replacement.respond_to?(:call) ? replacement.call(*args, **kwargs, &block) : replacement
    end
    yield
  ensure
    target.define_singleton_method(method_name, original) if original
  end
end
