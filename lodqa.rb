#!/usr/bin/ruby
#encoding: UTF-8
require './enju'
require 'net/http'
require 'json'

class QueryParser
  def initialize (enju_url, ontofinder_url)
    @enju = Enju.new(enju_url)
    @ontofinder = ontofinder_url
  end

  # gsparql: generalized sparql
  def parse (query)
    @query = query
    @enju.parse(query)
    @enju.gen_pasgraph("_pas_graph.png")

    @head  = @enju.get_head
    bnp   = @enju.get_bnp
    @rel   = @enju.get_rel
    @focus = @enju.get_focus

    ###### psparql = Sparql.pseudo(head, bnp, rel, focus)
    ## delete 'me', in, e.g. "find me" or "show me"
    @head.delete_if {|h| @enju.idx_get_word(h) == 'me'}
    @rel.delete_if {|s, p, o| (@enju.idx_get_word(s) == 'me') or (@enju.idx_get_word(o) == 'me')}

    ## terms
    @tvars = Hash.new            # term variables
    @texps = Hash.new            # term expressions

    v = 't1'
    @head.each do |h|
      @tvars[h] = v
      v = v.next

      words = @enju.idxv_get_word(bnp[h])
      words.delete_if {|w| w == 'a' || w == 'the' || w == 'some'} # stopword deletion
      @texps[h] = (words.empty?)? '' : words.join(' ')
    end


    ## preds
    @pvars = Hash.new           # predicate variables
    @pexps = Hash.new           # predicate expressions

    v = 'r1'
    @rel.each do |s, p, o|
      @pvars[p] = v
      v = v.next

      words = @enju.idxv_get_word(p)
      @pexps[p] = (words.empty?)? '' : words.join(' ')
    end
  end


  def get_query_with_bncs
    bnc_so = @enju.get_bnc_so

    so = []
    bnc_so.each {|c| so << c.push("BNC")}

    atext, last = '', 0
    so.each do |cbeg, cend, label|
      atext += @query[last...cbeg]
      atext += "<span class='#{label}'>"
      atext += @query[cbeg...cend]
      atext += '</span>'
      last = cend
    end
    atext += @query[last..-1]
  end


  def get_bncs
    bnc_so = @enju.get_bnc_so

    terms = Array.new
    bnc_so.each do |cbeg, cend|
      terms.push @query[cbeg...cend]
    end

    terms
  end


  ## pseudo sparql
  def get_psparql
    psparql = "SELECT ?#{@tvars[@focus]}\nWHERE {\n"
    @head.each {|h| psparql += "   ?#{@tvars[h]} rdf:type [#{@texps[h]}] . \n"} # instantiation
    @rel.each {|s, p, o| psparql += "   ?#{@tvars[s]} [#{@pexps[p]}] ?#{@tvars[o]} . \n"} # relation
    psparql += "}"
    @psparql = psparql
  end


  # sparql
  def get_sparql(vid, acronym)
    find_term_uris(vid) unless defined? @turis

    sparql = <<SPARQL
SELECT ?#{@tvars[@focus]} ?l1
WHERE {
  GRAPH <http://bioportal.bioontology.org/ontologies/#{acronym}> {
SPARQL

    v = 'd0'

    # instantiation
    @head.each do |h|
      next if @turis[h].empty?
      
      sparql += "    ?#{@tvars[h]} ?#{v.next!} <#{@turis[h].first}> .\n"
    end

    @rel.each {|s, p, o| sparql += "    ?#{@tvars[s]} ?#{@pvars[p]} ?#{@tvars[o]} .\n"} # relation

    sparql += <<-SPARQL
    ?#{@tvars[@focus]} <http://www.w3.org/2004/02/skos/core#prefLabel> ?l1 .
  }
}
SPARQL

  end

  def find_term_uris(vid)
    terms = Array.new
    @head.each {|h| terms.push @texps[h]}
    rsc = "#{@ontofinder}/mappings.json"
    RestClient.post rsc, {:data => terms.join("\n"), :vids => vid.to_s}, :content_type => 'multipart/form-data', :accept => :json do |response, request, result|
      case response.code
      when 200
        uris = JSON.parse(response)
        @turis = Hash[@head.zip(uris)]       # term URIs
      else
        @turis = nil
      end
    end
  end

end


if __FILE__ == $0

  ## configuration
  require 'parseconfig'
  config = ParseConfig.new('./lodqa.cfg')
  endpoint_url   = config['endpointURL']
  enju_url       = config['enjuURL']
  ontofinder_url = config['ontofinderURL']
  query          = config['testQuery']

  ## query from the command line
  query = ARGV[0] unless ARGV.empty?

  qp = QueryParser.new(enju_url, ontofinder_url)
  qp.parse(query)
  psparql = qp.get_psparql
  puts psparql

  sparql  = qp.get_sparql
  puts sparql

  ## result
  require 'sparql/client'
  endpoint = SPARQL::Client.new(endpoint_url)
  result = endpoint.query(sparql)
  result.each {|s| puts s[:t1] + "\t" + s[:l1]}
end