require 'webrick'
require ENV['TM_SUPPORT_PATH']+ '/lib/osx/plist'

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
    if query['doc'] == 'cocoa'
      if query['method']
       doc = generateOBJCDocumentation(query['method'], "div", 1)
      elsif query['constant']
        doc = generateOBJCDocumentation(query['constant'], "div", 0)
      elsif query['query']
        doc = generateOBJCDocumentation(query['function'], "div", 0)
      end
      content = {"documentation"=> doc} unless doc.nil?    
    end

    return 200, "text/plain", content.to_plist
  end

  def generateOBJCDocumentation( symbol, tag, count)
       begin
         docset_cmd = "/Developer/usr/bin/docsetutil search -skip-text -query "
         sets =  [
           "/Developer/Documentation/DocSets/com.apple.adc.documentation.AppleSnowLeopard.CoreReference.docset",
           "/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.CoreReference.docset",
         ]

         docset = sets.find do |candidate| 
           FileTest.exist?(candidate)
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
         str = open(url, "r").read

         searchTerm = "<a name=\"#{anchor}\""
         startIndex = str.index(searchTerm)
         return str if startIndex.nil?
         #return str[startIndex.. startIndex + 200]
         # endIndex = str.index("<a name=\"//apple_ref/occ/", startIndex + searchTerm.length)
         endIndex = find_end_tag(tag ,str, startIndex, count)  
         return nil if endIndex.nil?
         return str[startIndex...endIndex]
         
       rescue Exception => e
         return "error when generating documentation>" + selection.inspect + e.message + e.backtrace.inspect + symbol + ">>>"+object + url
       end
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
  s.shutdown
end
