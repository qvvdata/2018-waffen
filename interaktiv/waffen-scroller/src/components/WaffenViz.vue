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
      :groformat="groformat"
      />
  </div>
</template>

<script>
import * as topojson from "topojson-client";
import L from "leaflet";
import * as scale from "d3-scale";
import "leaflet-swoopy";
import "leaflet-responsive-popup";
import { GestureHandling } from "leaflet-gesture-handling";
require("../BoundaryCanvas.js");
import TreemapFocus from "../components/TreemapFocus.vue";
import world from "../data/ne_world_full_selectattr_topo.json";
import world_disputed from "../data/ne_world_disputed_selectattr_topo.json";
import austria_exports from "../data/exports_countries.csv";
import austria_companies from "../data/companies_geocoded.csv";
import scaleCluster from "d3-scale-cluster";
import * as d3 from "d3";
import exports_sumat from "../data/exports_sumat.csv";

L.Map.addInitHook("addHandler", "gestureHandling", GestureHandling);

austria_companies.sort(
  (a, b) =>
    (parseInt(b.beschaeftigte, 10) || 0) - (parseInt(a.beschaeftigte, 10) || 0)
);

exports_sumat.sort((a, b) => {
  return a.name == "Andere" ? 1 : b.name == "Andere" ? -1 : b.value - a.value;
});

var rscale = scale
  .scaleThreshold()
  .domain([50, 200])
  .range([6, 10, 20]);

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
      .range(["#CBCFCD", "#EFD594", "#78CDDB", "#E98895", "#ADC196"])
      .domain(exports_sumat.map(d => d.name)),
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

      if (this.auswahl) {
        if (iw < 500) {
          h = iw * 0.9;
        }
        if (iw < 300) {
          h = 280;
        }
      } else {
        if (iw > 700) {
          h = window.innerHeight * 0.6;
        } else {
          h = window.innerHeight * 0.4;
        }
      }

      this.height = h;
    },
    groformat(z) {
      var gro = ["", " Tsd.", " Mio.", " Mrd."];
      var i = 0;
      var y = z;
      while (y > 1000 && i < gro.length - 1) {
        y = (y * 1.0) / 1000;
        i++;
      }
      return `${this.$fmt(",.2r")(y)}${gro[i]}`;
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

      if (["map3", "map4"].indexOf(this.state) >= 0) {
        this.gj2.setStyle(x => {
          var r = this.relevant_exports.filter(
            d =>
              d.iso_destination_country == x.properties.ISO_A2 ||
              d.iso_destination_country_3 == x.properties.SOV_A3 ||
              d.iso_destination_country_3 == x.properties.ISO_A3_EH
          )[0];

          if (!r) {
            return {
              color: "#eaeaea",
              fillOpacity: 1,
              fillColor: "transparent"
            };
          } else {
            r.has_feature = true;
            all_relevant_features.push(x);
            return {
              fillColor: this.chloroplethscale(r.mlsum),
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
          weight: 0.5,
          color: "#bababa",
          opacity: 1,
          fillOpacity: 0
        });
      }

      if (this.state == "map1") {
        if (!this.legend._map) {
          this.legend.addTo(this.map);
        }
      } else {
        if (this.legend._map) {
          this.map.removeControl(this.legend);
        }
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
                paddingTopLeft: [45, 0],
                paddingBottomRight: [0, 15]
              }
            );
          }, 500);
        });
      }
      if (this.state == "map3") {
        // exporte choropleth
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
            x =>
              x.iso_destination_country == feature.properties.ISO_A2 ||
              x.iso_destination_country_3 == feature.properties.SOV_A3 ||
              x.iso_destination_country_3 == feature.properties.ISO_A3_EH
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
                        }: € ${this.$fmt(",d")(r.mlsum)}</${
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
        this.relevant_companies.map(d => {
          var otherbranches = austria_companies.filter(x => x.Name == d.Name);
          return new L.CircleMarker([d.lat, d.long], {
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
              `<h3>${d.Name}</h3>
                          ${
                            d.Beschreibung != "NA"
                              ? d.Beschreibung + "<br />"
                              : ""
                          }
                          Beschäftigte${
                            d.beschaeftigte_jahr != "NA"
                              ? ` ${d.beschaeftigte_jahr}`
                              : ""
                          }: ${d.beschaeftigte}<br />
                          Branchen: ${otherbranches
                            .map(
                              d2 =>
                                `<${d2.typ == d.typ ? "b" : "span"}>${
                                  d2.typ
                                }</${d2.typ == d.typ ? "b" : "span"}>`
                            )
                            .join(", ")}
                        `
            )
          );
        })
      );

      var top3exports = this.relevant_exports.slice(0, 3).map((d, i) => [
        d,
        L.swoopyArrow(
          [48.210033, 16.363449],
          [d.lat_destination_country, d.long_destination_country],
          {
            weight: 3 - i,
            label: `${d.name_destination_country}: ${this.groformat(d.mlsum)}`,
            labelAt: "to",
            iconAnchor: [d.iso_destination_country == "CZ" ? 0 : 50, 20],
            labelClassName: `swoopy_lbl ${d.iso_destination_country}`,
            color: "#888"
          }
        ),
        L.marker([d.lat_destination_country, d.long_destination_country]),
        this.allfeatures.features.filter(
          x =>
            d.iso_destination_country == x.properties.ISO_A2 ||
            d.iso_destination_country_3 == x.properties.SOV_A3 ||
            d.iso_destination_country_3 == x.properties.ISO_A3_EH
        )[0]
      ]);

      this.top3layers_fg = L.featureGroup(top3exports.map(d => d[2]));
      this.top3layers_lg = L.layerGroup(top3exports.map(d => d[1]));
      this.top3layers_g = L.geoJson(
        {
          type: "FeatureCollection",
          features: top3exports.map((d, i) => {
            var r = d[3];
            r.style = {
              color: this.chloroplethscale(+top3exports[i][0].mlsum),
              stroke: "transparent",
              opacity: 0,
              fillOpacity: 1,
              interactive: false
            };
            return r;
          })
        },
        {
          style: function(a) {
            return a.style;
          }
        }
      );

      var legend = L.control({ position: "bottomleft" });
      legend.onAdd = () => {
        var div = L.DomUtil.create("div", "info legend");
        var color = d3.hsl(this.colorscale(this.zoom_to));
        color.l = Math.min(color.l, 0.5);

        var c0 = d3.rgb(color);
        c0.opacity = 0.5;

        var c1 = d3.rgb(color);
        c1.opacity = 0.7;

        var ih1 = rscale
          .range()
          .map(
            (
              d,
              i
            ) => `<div style="display: inline-block; vertical-align: baseline;"><span style="border-radius: ${d}px;
                                width: ${d}px;
                                height: ${d}px;
                                display: inline-block;
                                background: ${c0};
                                border: 2px solid ${c1};
                                vertical-align: baseline;
                                margin-left: 1px;
                                margin-right: 2px;
                              "></span>${
                                rscale.domain()[i] ? rscale.domain()[i] : ""
                              }</div>`
          )
          .join("");

        c0 = d3.rgb("#2e3f37");
        c0.opacity = 0.5;

        c1 = d3.rgb("#2e3f37");
        c1.opacity = 0.7;

        div.innerHTML = `<b>Mitarbeiter:</b> ?: <span style="border-radius: 5px;
                              width: 5px;
                              height: 5px;
                              display: inline-block;
                              background: ${c0};
                              border: 2px solid ${c1};
                              vertical-align: baseline;
                            "></span> | 0${ih1}`;

        return div;
      };

      if (this.legend) {
        if (this.legend._map) {
          this.map.removeControl(this.legend);
        }
      }

      this.legend = legend;
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
    },
    chloroplethscale() {
      var colorscale = scaleCluster();
      if (this.zoom_to) {
        colorscale = colorscale
          .domain(
            this.relevant_exports.map(d => +d.mlsum).sort((a, b) => a - b)
          )
        .range(['#e0e0e0','#bbbfbd','#979e9b','#757f7a','#54615b']); // eslint-disable-line
      }
      return colorscale;
    }
  },
  mounted() {
    this.on_resize();
    const parent = this.$el.querySelector(".map");

    var map = L.map(parent, {
      zoomSnap: 0.1,
      zoomDelta: 1,
      zoomControl: this.auswahl,
      zoom: this.auswahl,
      pan: this.auswahl,
      gestureHandling: this.auswahl,
      gestureHandlingOptions: {
        text: {
          touch: "Verwenden Sie zwei Finger, um die Karte zu zoomen.",
          scroll: "Verwenden Sie Ctrl + Scrollen, um die Karte zu zoomen.",
          scrollMac: "Verwenden Sie \u2318 + Scrollen, um die Karte zu zoomen."
        }
      }
    });
    if (this.auswahl) {
      map.zoomControl.setPosition("topright");
    }
    map.attributionControl.setPrefix(false);
    map.getRenderer(map).options.padding = 2;
    if (!this.auswahl) {
      map._handlers.forEach(function(handler) {
        handler.disable();
      });
    }

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
@import "~leaflet-gesture-handling/dist/leaflet-gesture-handling.css";

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
.swoopy_lbl.CZ {
  text-align: left;
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
