<template>
  <div class="WaffenViz" :style="`height: ${this.height}px`">
    <!-- <div :style="`width: 100%; height: 100%; background: ${this.zoom_to && this.auswahl ? colorscale(this.zoom_to) : 'rgba(255,255,255,0)'}`"></div> -->
    <div
      class="map"
      :style="`opacity: ${show_map?1:0.01}`">
    </div>
    <TreemapFocus
      v-if="show_treemap"
      :zoom_to="state != 'init' ? zoom_to : null"
      @zoom_to_change="zoom_to_change"
      :style="state != 'init' && state != 'map1' && auswahl ? 'opacity: 0.5' : ''"
      :auswahl="auswahl"
      :colorscale="colorscale"
      />
  </div>
</template>

<script>
import * as topojson from "topojson-client";
import L from "leaflet";
import * as scale from "d3-scale";
import "leaflet-swoopy";
import "leaflet-responsive-popup";
require("../BoundaryCanvas.js");
import TreemapFocus from "../components/TreemapFocus.vue";
import world from "../data/ne_world_full_selectattr_topo.json";
import world_disputed from "../data/ne_world_disputed_selectattr_topo.json";
import austria_exports from "../data/exports_countries.csv";
import austria_companies from "../data/companies_geocoded.csv";
import scaleCluster from "d3-scale-cluster";
import * as d3 from "d3";

austria_companies.sort(
  (a, b) =>
    (parseInt(b.beschaeftigte, 10) || 0) - (parseInt(a.beschaeftigte, 10) || 0)
);

var rscale = scale
  .scaleThreshold()
  .range([3, 6, 10, 20])
  .domain([0, 50, 200]);

export default {
  name: "WaffenViz",
  props: {
    auswahl: {
      type: Boolean,
      default: true
    },
    zoom_to: {
      type: String,
      default: null
    },
    state: {
      type: String,
      default: "init"
    }
  },
  data: () => ({
    colorscale: scale
      .scaleOrdinal()
      .range(["#CBCFCD", "#EFD594", "#78CDDB", "#E98895", "#ADC196"]),
    has_popup: false,
    height: 500
  }),
  components: {
    TreemapFocus
  },
  methods: {
    on_resize() {
      var h = 450;
      var iw = this.$el.clientWidth;
      if (iw < 500) {
        h = iw * 0.9;
      }
      if (iw < 300) {
        h = 280;
      }
      this.height = h;
    },
    zoom_to_change($event) {
      if (!this.auswahl) {
        return;
      }
      if (this.zoom_to == $event) {
        this.zoom_to = null;
        this.state = "init";
      } else {
        this.zoom_to = $event;
        this.state = "map1";
      }
    },
    main_layers() {
      return [
        this.tlbc, // austria-limited TileLayer
        this.gj2, // countries
        this.gj3, // disputed areas
        this.companycircles, // company circles
        this.top3layers_g, // top 3 countries
        this.top3layers_lg // top 3 arrows
      ];
    },
    show_layers(l) {
      var ml = this.main_layers();
      l.map(l2 => {
        l2.addTo(this.map);
        if (ml.indexOf(l2) < 0) {
          console.log("not in main layers", l2);
        }
      });
      ml.filter(l2 => l.indexOf(l2) < 0)
        .filter(l2 => this.map.hasLayer(l2))
        .map(l => this.map.removeLayer(l));
    },
    update() {
      this.$nextTick(this.update_real);
    },
    update_real() {
      if (this.timeout) {
        clearTimeout(this.timeout);
        this.timeout = null;
      }
      this.map.invalidateSize(false);

      var all_relevant_features = [];
      var colorscale = scaleCluster();
      if (this.zoom_to) {
        colorscale = colorscale
          .domain(
            this.relevant_exports.map(d => +d.mlsum).sort((a, b) => a - b)
          )
        .range(["#a5dde7", "#93d3e0", "#80cad9", "#6cc0d2", "#56b7cb", "#08a4bd"]); // eslint-disable-line
      }

      if (["map3", "map4"].indexOf(this.state) >= 0) {
        this.gj2.setStyle(d => {
          var r = this.relevant_exports.filter(
            x => x.iso_destination_country == d.properties.ISO_A2
          )[0];

          if (!r) {
            return {
              color: "#eaeaea",
              fillOpacity: 1,
              fillColor: "transparent"
            };
          } else {
            r.has_feature = true;
            all_relevant_features.push(d);
            return {
              fillColor: colorscale(r.mlsum),
              fillOpacity: 1,
              color: "#ffffff",
              weight: 0.5,
              opacity: 1
            };
          }
        });
      } else {
        this.gj2.setStyle({
          fillColor: "transparent",
          weight: 1,
          color: "black",
          opacity: 1,
          fillOpacity: 0
        });
      }
      if (this.state == "init") {
        // treemap
        this.show_layers([this.tlbc]);
      }
      if (this.state == "map1") {
        // map + treemap
        this.show_layers([this.tlbc, this.companycircles]);

        this.$nextTick(() => {
          this.map.flyToBounds(this.gj.getBounds(), {
            animate: true,
            duration: 0.5
          });
        });
      }
      if (this.state == "map2") {
        // exporte top3
        this.$nextTick(() => {
          this.show_layers([
            this.gj2,
            this.gj3,
            this.top3layers_g,
            this.top3layers_lg
          ]);
          this.map.invalidateSize(false);
          this.timeout = setTimeout(() => {
            this.map.flyToBounds(
              this.top3layers_fg.getBounds().extend(this.gj.getBounds()),
              {
                animate: true,
                duration: 0.5,
                padding: [40, 40]
              }
            );
          }, 500);
        });
      }
      if (this.state == "map3") {
        // exporte choropleth
        console.log(this.relevant_exports.filter(d => !d.has_feature));
        this.show_layers([this.gj2, this.gj3]);
        this.map.flyToBounds(
          L.geoJson({
            type: "FeatureCollection",
            features: all_relevant_features
          }).getBounds(),
          { animate: true, duration: 0.5 }
        );
      }
    },
    make_layers() {
      var allfeatures = topojson.feature(
        world,
        world.objects[Object.keys(world.objects)[0]]
      );
      var oesterreich = allfeatures.features.filter(
        d => d.properties.ISO_A3 == "AUT"
      );

      var tlbc = new L.TileLayer.BoundaryCanvas(
        "https://api.mapbox.com/styles/v1/qvv/cjlf9u2558zbs2rs0qmopzt80/tiles/{z}/{x}/{y}?access_token={accessToken}",
        {
          attribution: "&copy; OpenStreetMap / Mapbox",
          id: "qvv/cjlf9u2558zbs2rs0qmopzt80",
          accessToken:
            "pk.eyJ1IjoicXZ2IiwiYSI6ImNqNnJvejZ6ZzBiZ3UzM2xhYnNoZW0ydWIifQ._qWkkHhqybK5dgvfkGdZDg",
          boundary: oesterreich[0],
          tileSize: 256
        }
      );

      var gj = L.geoJson(
        allfeatures.features.filter(d => d.properties.ISO_A3 == "AUT")
      );
      var gj2 = L.geoJson(allfeatures, {
        interactive: true,
        attribution: "NaturalEarth",
        onEachFeature: (feature, layer) => {
          var r = austria_exports.filter(
            x => x.iso_destination_country == feature.properties.ISO_A2
          );
          if (r.length > 0) {
            layer.bindPopup(
              L.responsivePopup({
                maxWidth: Math.min(300, window.innerWidth * 0.8)
              }).setContent(
                `<h3>${feature.properties.NAME_DE}</h3>` +
                  r
                    .map(
                      r =>
                        `<${this.zoom_to == r.wkdok ? "b" : "span"}>${
                          r.wkdok
                        }: ${this.$fmt(",d")(r.mlsum)}</${
                          this.zoom_to == r.wkdok ? "b" : "span"
                        }>`
                    )
                    .join("<br/>")
              )
            );
          }
        }
      });
      var gj3 = L.geoJson(
        topojson.feature(
          world_disputed,
          world_disputed.objects[Object.keys(world_disputed.objects)[0]]
        ),
        {
          style: {
            color: "lightgrey",
            opacity: 1,
            fillOpacity: 1
          },
          interactive: false
        }
      );

      this.tlbc = tlbc;
      this.gj = gj;
      this.gj2 = gj2;
      this.gj3 = gj3;
      this.allfeatures = allfeatures;

      var color = d3.hsl(this.colorscale(this.zoom_to));
      color.l = Math.min(color.l, 0.5);
      this.companycircles = L.featureGroup(
        this.relevant_companies.map(d =>
          new L.CircleMarker([d.lat, d.long], {
            radius: isNaN(parseInt(d.beschaeftigte, 10))
              ? 5
              : rscale(d.beschaeftigte),
            color: isNaN(parseInt(d.beschaeftigte)) ? "#2e3f37" : color,
            opacity: 0.7,
            fillOpacity: 0.5,
            weight: 2,
            stroke: true
          }).bindPopup(
            L.responsivePopup({
              maxWidth: Math.min(300, window.innerWidth * 0.8)
            }).setContent(
              `<h3>${d.name}</h3>
              ${d.beschaeftigte}<br />
              ${d.typ}<br />
              ${d.beschreibung}
            `
            )
          )
        )
      );

      var top3exports = this.relevant_exports.slice(0, 3).map(d => [
        d,
        L.swoopyArrow(
          [48.210033, 16.363449],
          [d.lat_destination_country, d.long_destination_country],
          {
            weight: Math.log(d.mlsum) / 10,
            label: d.name_destination_country,
            labelAt: "to",
            iconAnchor: [50, 15],
            labelClassName: "swoopy_lbl"
          }
        ),
        L.marker([d.lat_destination_country, d.long_destination_country]),
        this.allfeatures.features.filter(
          x => x.properties.ISO_A2 == d.iso_destination_country
        )[0]
      ]);

      this.top3layers_fg = L.featureGroup(top3exports.map(d => d[2]));
      this.top3layers_lg = L.layerGroup(top3exports.map(d => d[1]));
      this.top3layers_g = L.geoJson(
        { type: "FeatureCollection", features: top3exports.map(d => d[3]) },
        {
          style: {
            color: "blue",
            stroke: "transparent",
            opacity: 0,
            interactive: false
          }
        }
      );
    }
  },
  watch: {
    state() {
      this.update();
    },
    zoom_to() {
      this.show_layers([]);
      this.make_layers();
    }
  },
  computed: {
    show_map() {
      return this.state != "init";
    },
    show_treemap() {
      return !this.has_popup; //this.state == "init" || this.state == "map1";
    },
    relevant_exports() {
      return austria_exports.filter(d => d.wkdok == this.zoom_to);
    },
    relevant_companies() {
      return austria_companies.filter(d => d.typ.indexOf(this.zoom_to) >= 0);
    }
  },
  mounted() {
    this.on_resize();
    const parent = this.$el.querySelector(".map");

    var map = L.map(parent, {
      zoomSnap: 0.25,
      zoom: false,
      pan: false,
      zoomControl: false
    });
    map.attributionControl.setPrefix(false);
    map.getRenderer(map).options.padding = 2;
    map._handlers.forEach(function(handler) {
      handler.disable();
    });

    this.map = map;

    map.on("popupopen", () => (this.has_popup = true));
    map.on("popupclose", () => (this.has_popup = false));

    this.make_layers();

    map.fitBounds(this.gj.getBounds());
    this.update();
  }
};
</script>

<style>
@import "~leaflet/dist/leaflet.css";
@import "~leaflet-responsive-popup/leaflet.responsive.popup.css";

.WaffenViz {
  position: relative;
}

.TreemapFocus {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.leaflet-container {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  background: none;
  height: 100%;
  width: 100%;
  max-width: 1000px;
  margin-left: auto;
  margin-right: auto;
  font: 12px/1.5 Sailec, "Helvetica Neue", Arial, Helvetica, sans-serif;
  overflow: hidden;
}

.leaflet-popup-content h3 {
  margin: 5px 0 5px 0;
}

.leaflet-popup-content {
  margin: 0px 10px 5px;
}
.leaflet-popup-content-wrapper {
  border-radius: 5px;
  box-shadow: -1px -1px 0px lightgrey, 1px 1px 0px lightgrey,
    1px -1px 0px lightgrey, -1px 1px 0px lightgrey;
}
.leaflet-container a.leaflet-popup-close-button {
  padding: 1px 1px 0 0;
}

.leaflet-overlay-pane svg {
  animation: fadein 0.5s;
}

@keyframes fadein {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.swoopy_lbl {
  text-align: right;
}

.leaflet-container {
  z-index: 2;
}

.TreemapFocus {
  z-index: 3;
}

.leaflet-marker-icon {
  line-height: 1em;
  font-weight: bold;
}
</style>
