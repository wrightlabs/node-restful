_ = require 'underscore'
handlers = require './handlers'
app = require './app'
filters = require './filters'
Route = require './route'

class Resource
  # The built in methods that we support
  @ALL_ROUTES:
    "list": Route.makeRoute('', 'get', handlers.list, false)
    "detail": Route.makeRoute('', 'get', handlers.detail, true)
    "update": Route.makeRoute('', 'put', handlers.update, true)
    "create": Route.makeRoute('', 'post', handlers.create, false)
    "destroy": Route.makeRoute('', 'delete', handlers.destroy, true)

  @ALL_METHODS: ['get', 'put', 'post', 'delete']

  constructor: (@resourceName, @Model) ->
    @routes = []

  withRoutes: (newRoutes) ->
    if @addedRoutes
      throw new Error("Cannot register built in routes more than once")

    newRoutes = @arrayify(newRoutes)
    validRoutes = Object.keys(Resource.ALL_ROUTES)
    
    routes = _.map newRoutes, (routeName) =>
      unless routeName in validRoutes
        throw new Error("'#{routeName}' not recognized as built in route. " +
          "Valid choices are [#{validRoutes}]")

      Resource.ALL_ROUTES[routeName]

    routes.forEach _.bind(@insertRoute, @)
    @addedRoutes = true
    @

  arrayify: (maybeNotArray) ->
    if _.isArray(maybeNotArray) then maybeNotArray else [maybeNotArray]

  # Not sure what this is meant to be
  #baseUrl: (@resourceName) ->
  #  @

  route: (path, methods, detail, fn) ->
    if arguments.length == 2
      # route(path, fn)
      fn = methods
      methods = ['get']
      detail = false
    else if arguments.length == 3
      # route(path, methods, fn)
      [detail, fn] = [false, detail]

    methods = [methods] unless _.isArray(methods)
    methods.forEach (method) =>
      route = Route.makeRoute(path, method, fn, detail)
      route = @insertRoute(route)
    @

  @addMiddleware: (beforeOrAfter) ->
    (path, methods, detail, fn) ->
      methods = @arrayify(methods)
      methods.forEach (method) =>
        existingRoute = @findRoute(path, method, detail)
        unless existingRoute
          throw new Error("Trying to add #{beforeOrAfter} middleware on an " +
            "unregistered route (#{path},#{method},isDetail=#{detail})")
        existingRoute[beforeOrAfter](fn)
      @

  before: Resource.addMiddleware('before')
  after: Resource.addMiddleware('after')

  findRoute: (path, method, detail) ->
    if (path?.length > 0 and path.charAt(0) != '/')
      path = "/#{path}"
    _.findWhere @routes, path: path, method: method, detail: detail

  insertRoute: (route) ->
    existingRoute = @findRoute(route.path, route.method, route.detail)
    unless existingRoute
      @routes.push route
    else
      throw new Error("Trying to register route twice. " +
        "#{existingRoute} already registered. #{route} ignored")

  register: () ->
    unless @addedRoutes
      console.log('No built in routes specified. Adding list and detail routes')
      @withRoutes('list', 'detail')

    @routes.forEach _.bind(@registerRoute, @)

  registerRoute: (route) ->
    return unless route.handler
    url = "/#{@resourceName}#{route.url()}"
    app[route.method](url, @makeHandler(route))

  makeHandler: (route) ->
    return [_.bind(handlers.preprocess, @)].concat(
      _.map(route.handlers(), (handler) => _.bind(handler, @)),
      _.bind(handlers.last, @)
    )

  filter: (req, query = @Model.find({})) ->
    detail = req.params.id?
    query = @Model.findById(req.params.id) if req.params.id
    [req.body, req.query, req.headers].forEach (requestData) ->
      for key, value of requestData
        query = filters.filter(key, value, detail, query)

    query

  setRemoveOptions: (@removeOptions) ->
    @
  setUpdateOptions: (@updateOptions) ->
    @

exports = module.exports = Resource
