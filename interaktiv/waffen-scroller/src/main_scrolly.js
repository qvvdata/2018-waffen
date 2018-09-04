import Vue from "vue";
import WaffenViz from "./components/WaffenViz.vue";
import * as format from "d3-format";
import steps from "./data/steps.archieml";

import { graphScroll } from "./graph-scroll.js";
import * as d3 from "d3";
require("./scrolly.css");

const locale = format.formatDefaultLocale({
  decimal: ",",
  thousands: ".",
  grouping: [3],
  currency: ["", "\u00a0€"]
});
Vue.prototype.$fmt = locale.format;
console.log();

Vue.config.productionTip = false;
if(document.currentScript) {
  Vue.prototype.$base_url = document.currentScript.src.split('/').slice(0,-2).join('/');
}

Array.prototype.map.call(document.querySelectorAll(".qvv_embed_scrolly"), e => {
  var parent = d3.select(e);
  var this_steps = steps[parent.attr("data-which")];
  parent.append("div").attr("class", "graphcontainer");

  var c = Vue.extend(WaffenViz);

  var v1 = new c({
    propsData: {
      auswahl: false,
      state: "init",
      zoom_to: this_steps[0].zoom_to
    }
  });

  v1.$set(v1, "state", "map1");
  v1.$mount(
    parent
      .select(".graphcontainer")
      .append("div")
      .node()
  );

  parent
    .append("div")
    .attr("class", "container")
    .append("div")
    .attr("class", "sections")
    .selectAll("div")
    .data(this_steps)
    .enter()
    .append("div")
    .html(d => d.text);
  var gs = graphScroll();
  gs.graph(parent.select(".graphcontainer"))
    .container(parent)
    .sections(parent.selectAll(".container .sections > div"))
    .offset(-25)
    .on("active", i => {
      i = i >= 0 ? i : 0;
      var graph = this_steps[i].graph;

      v1.$set(v1, "state", graph);
    });

  window.gs = gs;

  setInterval(gs.resize, 2000);
});
