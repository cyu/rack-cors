CORS_SERVER = 'cors-server:3000'

describe 'CORS', ->

  it 'should allow access to dynamic resource', (done) ->
    $.get "http://#{CORS_SERVER}/", (data, status, xhr) ->
      expect(data).to.eql('Hello world')
      done()

  it 'should allow access to static resource', (done) ->
    $.get "http://#{CORS_SERVER}/static.txt", (data, status, xhr) ->
      expect($.trim(data)).to.eql("hello world")
      done()

  it 'should allow post resource', (done) ->
    $.post "http://#{CORS_SERVER}/cors", (data, status, xhr) ->
      expect($.trim(data)).to.eql("OK!")
      done()

