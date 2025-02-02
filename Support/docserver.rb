require 'webrick'
require ENV['TM_SUPPORT_PATH']+ '/lib/osx/plist'
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"


class Simple < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server)
    super(server)
    @idle = false
    Thread.new do
      until @idle
        @idle = true
        sleep(5.0*60.0)
      end
      server.shutdown 
    end
  end
  
  def do_GET(request, response)
    @idle = false
    status, content_type, body = do_stuff_with(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def do_stuff_with(request)
    query = request.query
    content = {}
    doc = nil
    if query['doc'] == 'cocoa'
      if query['method']
       doc = generateOBJCDocumentation(query['method'], "div", 1)
      elsif query['constant']
        doc = generateOBJCDocumentation(query['constant'], "div", 0)
      elsif query['function']
        doc = generateOBJCDocumentation(query['function'], "div", 0)
      elsif query['class']
        doc = generateCocoaClassDocumentation(query['class'])
      end
      
    elsif query['doc'] == 'cpp'
      if query['function']
        doc = fetchCPPFunctionDocumentation(query['function'])
      end
    end
    content = {"documentation"=> doc} unless doc.nil?

    return 200, "text/plain", content.to_plist
  end
  
  def fetchCPPFunctionDocumentation(function_name)
    name = ENV['TM_BUNDLE_SUPPORT'] + "/CppReferenceWiki.tsf"
    url = %x{grep -e ^#{e_sh function_name }"[[:space:]]" #{e_sh name}}.split("\n")
    if !url.empty?
      require 'open-uri'
      str =  open(url[0].split("\t")[2]).read

      searchTerm =  "<h2><a name=\"#{function_name}\" id=\"#{function_name}\">#{function_name}</a></h2>"
      startIndex = str.index(searchTerm)
      return str if startIndex.nil?
      
      endIndex = find_end_tag("div", str, startIndex,0) 
      return nil if endIndex.nil?
      
      return str[startIndex...endIndex]
    end
    nil
  end

  
  def generateCocoaClassDocumentation(symbol)
    url, anchor, os = run_command(symbol)
    return nil if url.nil?
    
    str = open(url, "r").read
    
    searchTerm = "<a name=\"#{anchor}\""
    startIndex = str.index(searchTerm)
    return str if startIndex.nil?
    
    searchTerm = "<div id=\"Tasks_section\""
    endIndex = str.index(searchTerm)
    return nil if endIndex.nil?
    
    return str[startIndex...endIndex]
    
  end
  
  def generateOBJCDocumentation( symbol, tag, count)
    begin
      url, anchor, os = run_command(symbol)
      return nil if url.nil?
      
      str = open(url, "r").read
    
      searchTerm = "<a name=\"#{anchor}\""
      startIndex = str.index(searchTerm)
      return str if startIndex.nil?
      #return str[startIndex.. startIndex + 200]
      # endIndex = str.index("<a name=\"//apple_ref/occ/", startIndex + searchTerm.length)
      #endIndex = find_end_tag(tag ,str, startIndex, count)
      if os == :snowleopard
        endIndex = find_declared_in(str, startIndex)
      elsif os == :leopard
        endIndex = find_end_tag("div",str, startIndex, 0)
      else
        return nil
      end
      return nil if endIndex.nil?
      return str[startIndex...endIndex]
      
    rescue Exception => e
      return "error when generating documentation>" + e.message + e.backtrace.inspect + symbol + url
    end
   end
   
   def run_command(symbol)
     docset_cmd = "/Developer/usr/bin/docsetutil search -skip-text -query "
     sets =  [
       ["/Developer/Documentation/DocSets/com.apple.adc.documentation.AppleSnowLeopard.CoreReference.docset",:snowleopard],
       ["/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.CoreReference.docset", :leopard],
     ]

     docset, os = sets.find do |candidate| 
       FileTest.exist?(candidate[0])
     end
     
     return nil if docset.nil?

     cmd = docset_cmd + symbol + ' ' + docset
     result = `#{cmd} 2>&1`

     status = $?
     return result if status.exitstatus != 0

     firstLine = result.split("\n")[0]
     urlPart = firstLine.split[1]
     path, anchor = urlPart.split("\#")

     url = docset + "/Contents/Resources/Documents/" + path
     return url, anchor, os
   end
   
   def find_declared_in(str, start)
     ix = str.index("<code class=\"HeaderFile\">", start)
     str.index("</code></div>",ix) unless ix.nil?
   end
   
   def find_end_tag(tag, string, start, count=0) 
     rgxp = /<(\/)?#{tag}/
     string = string[start..-1]
     offset = start
     while m = string.match(rgxp)
        if m[1]
          count -= 1
          puts m.begin(0)
        else
          count += 1
        end
        offset += m.end(0)

        return offset if count == 0
        string = m.post_match
     end
     nil
   end
end

class DocServer
  PORT = 60921
  def initialize
    server = WEBrick::HTTPServer.new(:Port => PORT, :BindAddress => '127.0.0.1')
    server.mount "/", Simple

    #trap "INT" do server.shutdown end
    server.start
  end
end
  

if $0 == __FILE__ then
  s=  DocServer.new
end
