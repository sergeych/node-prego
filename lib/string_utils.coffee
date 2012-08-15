###
  Heavily missing string utilities to change
  case style
###

String::snakeToCamelCase = ->
  parts = @split('_')
  parts[1..] = (p.toTitleCase() for p in parts[1..])
  parts.join('')

String::toTitleCase = ->
  @[0].toUpperCase() + @substring(1).toLowerCase()

String::camelToSnakeCase = ->
  @replace(/(.)([A-Z])/g, '$1_$2').toLowerCase()

pluralizePatterns = [
  ['(quiz)', '$1zes']
  ['^oxen', 'oxen']
  ['^ox', 'oxen']
  ['^blouse', 'blouses']
  ['(m|l)ice', '$1ice']
  ['(m|l)ouse', '$1ice']
  ['(matr|vert|ind)(?:ix|ex)', '$1ices']
  ['(x|ch|ss|sh)', '$1es']
  ['([^aeiouy]|qu)y', '$1ies']
  ['(hive)', '$1s']
  ['(?:([^f])fe|([lr])f)', '$1$2ves']
  ['sis', 'ses']
  ['([ti])a', '$1a']
  ['([ti])um', '$1a']
  ['(buffal|tomat)o', '$1oes']
  ['(bu)s', '$1ses']
  ['(alias|status)', '$1es']
  ['(octop|vir)i', '$1i']
  ['(octop|vir)us', '$1i']
  ['(ax|test)is', '$1es']
  ['s', 's']
  ['', 's']
]

pluralizeRules = ([ new RegExp(patt + '$', 'i'), end] for [patt, end] in pluralizePatterns)

String::pluralize = ->
  for [patt, end] in pluralizeRules when (m = @.match(patt))
    prefix = @[...m.index]
    (end = end.replace( "$#{i+1}", part || '')) for part, i in m[1..]
    return prefix + end
  return @

String::format = (args...) ->
  util.format @, args...

