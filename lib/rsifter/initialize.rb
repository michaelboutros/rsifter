module Sifter
  def detailed_return(detailed_return, input)
    if detailed_return
      return input
    else
      return input[:successful]
    end
  end
  
  module_function 'detailed_return'
end