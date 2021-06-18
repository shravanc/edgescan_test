# frozen_string_literal: true

require 'tsort' # HINT

# PermissionDependencyResolver takes in one argument dependencies
# It will sort it in a way that same dependency key will stay adjacent
# and then assign it to the instance variable
# example: argument to class PermissionDependencyResolver
#    {
#      'view' => [],
#      'edit' => ['view'],
#      'alter_tags' => ['edit'],
#      'create' => ['view'],
#      'delete' => ['edit']
#    }
# will assign it to the instance variable like below
#    {
#       'create'=>['view'],
#       'edit'=>['view'],
#       'delete'=>['edit'],
#       'alter_tags'=>['edit'],
#       'view'=>[]
#    }
class PermissionDependencyResolver
  include TSort
  attr_accessor :dependencies

  def initialize(dependencies)
    dependencies = dependencies.each { |_key, val| { _key => val.sort } }
    @dependencies = dependencies.sort_by { |_key, val| (val.size.positive? ? val[0] : '') }.reverse.to_h
  end

  # This function first validates existing permission to be in valid order
  # Existing permision should have dependent permission defined
  # If there is no dependency function returns "true" straight away
  # If there is a dependency for new permission to be granted it will be validated

  def can_grant?(existing, perm_to_be_granted)
    existing = validate_perm(existing)

    return true if dependencies[perm_to_be_granted].empty?

    # required dependencies matchs with existing substracting returns empty array
    # ['view'] - ['view'] = [] Dependency is met
    # ['view'] - [] = ['view'] Dependency is not met
    # ['view', 'edit'] - ['view'] = ['edit'] Dependency is not met
    # ['view'] - ['view', 'edit'] = [] Dependency is met
    (dependencies[perm_to_be_granted] - existing).empty?
  end

  # This function first validates existing permission to be in valid order
  # This checks if a permission can be removed?

  def can_deny?(existing, perm_to_be_denied)
    existing = validate_perm(existing)

    existing.each do |perm|
      return false if @dependencies[perm].include? perm_to_be_denied
    end
    true
  end

  def sort(permissions)
    (tsort & permissions)
  end

  private

  def tsort_each_node(&block)
    @dependencies.each_key(&block)
  end

  def tsort_each_child(node, &block)
    @dependencies[node].each(&block)
  end

  def validate_perm(existing)
    existing = sort(existing)
    existing.each_with_index do |perm, i|
      next if @dependencies[perm].empty?
      raise InvalidBasePermissionsError unless (@dependencies[perm] - existing[0..i]).empty?
    end
    existing
  end
end
