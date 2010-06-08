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
      doc = generateOBJCDocumentation(query['class'],query['method'])
      content = {"documentation"=> doc} unless doc.nil?    
    end

    return 200, "text/plain", content.to_plist
  end

  def generateOBJCDocumentation(class_name, method_name)
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

         object = class_name.match(/^[^;]+/)[0]

         cmd = docset_cmd + method_name + ' ' + docset
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
         endIndex = str.index("<a name=\"//apple_ref/occ/", startIndex + searchTerm.length)
         unless(startIndex && endIndex )
           return nil
         else
           return str[startIndex...endIndex]
         end
       rescue Exception => e
         return "error when generating documentation>" + selection.inspect + e.message + e.backtrace.inspect + method_name + ">>>"+object + url
       end
   end

end

class DocServer
  def initialize
    server = WEBrick::HTTPServer.new(:Port => 17753, :BindAddress => '127.0.0.1')
    server.mount "/", Simple

    #trap "INT" do server.shutdown end
    server.start
  end
end
  

if $0 == __FILE__ then
  s=  DocServer.new
  s.shutdown
end
