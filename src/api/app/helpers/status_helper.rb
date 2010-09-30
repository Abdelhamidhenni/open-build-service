module StatusHelper

  def self.resample(values, samples = 400)
    values.sort! {|a,b| a[0] <=> b[0]}

    result = Array.new
    return result unless values.length > 0

    lastvalue = 0
    now = values[0][0]
    samplerate = (values[-1][0] - now) / samples

    index = 0
    
    1.upto(samples) do |i|
      value = 0.0
      count = 0
      while index < values.length && values[index][0] < now + samplerate
	value += values[index][1]
	index += 1
	count += 1
      end
      if count > 0
	value = value / count
      else
	value = lastvalue
      end
      result << [now + samplerate / 2, value]
      now += samplerate
      lastvalue = value
    end
    
    return result
  end

end
