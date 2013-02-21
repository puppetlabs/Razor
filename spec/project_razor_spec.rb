require 'spec_helper'

describe Object, "extensions" do
  context ".class_children" do
    let :parent       do Class.new end
    let :child_class  do Class.new(parent) end
    let :child_module do Module.new end

    # This is actually quite horrible, but that is what it takes to test core
    # extensions.  This is why monkey-patching core is bad, m'kay.  --daniel
    # 2013-02-20
    before :each do
      parent.const_set("ChildClass",  child_class)
      parent.const_set("ChildModule", child_module)
      parent.const_set("ChildValue",  12)
      parent.const_set("ChildInstance", Object.new)
    end

    subject { parent }

    it { should respond_to "class_children" }
    its "class_children" do should =~ [child_class, child_module] end
  end

  context ".full_const_get" do
    it { should respond_to "full_const_get" }
  end
end
