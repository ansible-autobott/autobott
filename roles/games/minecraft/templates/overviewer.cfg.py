from .observer import MultiplexingObserver, LoggingObserver, JSObserver
global escape
from html import escape

# Define world paths
worlds["{{ minecraft_config.server.name }}"] = "{{ minecraft_config.paths.universe }}/{{ minecraft_config.server.name }}"
worlds["{{ minecraft_config.server.name }} - Nether"] = "{{ minecraft_config.paths.universe }}/{{ minecraft_config.server.name }}_nether"
worlds["{{ minecraft_config.server.name }} - The End"] = "{{ minecraft_config.paths.universe }}/{{ minecraft_config.server.name }}_the_end"

# Defaults
world = "{{ minecraft_config.server.name }}"
imgformat = "jpg"
imgquality = "85"

outputdir = "{{ minecraft_config.overviewer.output }}"
texturepath = "{{ minecraft_config.paths.base }}/overviewer/textures.zip"

# Filter functions
def POISignFilter(poi):
  if poi['id'] == 'Sign' or poi['id'] == 'minecraft:sign':
    if "POI" in poi['Text1']:
      return escape("\n".join([poi['Text1'], poi['Text2'], poi['Text3'], poi['Text4']]))

# Render modes
lit_cave = [Base(), EdgeLines(), Cave(only_lit=True), Lighting()]
biome_overlay = [ClearBase(), BiomeOverlay()]
better_nether = [Base(), EdgeLines(opacity=0.2), Nether(), Lighting(strength=0.32)]

# Renders
{% if minecraft_config.overviewer.renders is defined and minecraft_config.overviewer.renders|length %}
{% for item in minecraft_config.overviewer.renders %}
renders["{{ item.name }}"] = {
  "title": "{{ item.title }}",
  {% if item.dimension is defined and item.dimension|length %}"dimension": "{{ item.dimension }}",{% endif %}
{% if item.rendermode is defined and item.rendermode|length %}"rendermode": {{ item.rendermode | tojson }},{% endif %}
{% if item.world is defined and item.world|length %}"world": "{{ item.world }}",{% else %}"world": "{{ minecraft_config.server.name }}",{% endif %}
{% if item.northdirection is defined and item.northdirection|length %}"northdirection": "{{ item.northdirection }}",{% endif %}
"markers": [
  {% if minecraft_config.overviewer.pois %}
dict(name="Points of interest", filterFunction=POISignFilter, icon="markers/marker_base_plain_red.svg"),
{% endif %}
],
}
{% endfor %}
{% endif %}

# Observer setup
loggingObserver = LoggingObserver()
jsObserver = JSObserver(outputdir)
observer = MultiplexingObserver(loggingObserver, jsObserver)

