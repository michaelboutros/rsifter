module Sifter
  # This method allows other methods to return both an action value (ie. true, false, nil) and message if
  # Client.detailed_return is true, or only the action value if detailed_return is set to false. Client.detailed_return
  # is set to false by default.
  def detailed_return(detailed_return, input)
    if detailed_return
      return input
    else
      return input[:successful]
    end
  end
  
  module_function 'detailed_return'
end