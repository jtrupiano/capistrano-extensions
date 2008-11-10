
# Provides very basic rollback functionality for a class
module Rollbackable
  
  attr_reader :rollbacks
  def rollback!(method)
    @rollbacks.each do |r|
      r.call
    end
    clear!
  end
  
  def add_rollback(proc)
    @rollbacks << proc
  end
  
  def clear_rollbacks!
    @rollbacks = {}
  end  
  
end