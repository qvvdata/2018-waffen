import Vue from "vue";
import WaffenViz from "./components/WaffenViz.vue";
require("./qvv.css");
import * as pymembed from "./pymembed.js";

window.getEmbed = pymembed.getEmbed;

window.pymChild = new pym.Child(); // eslint-disable-line

import * as format from "d3-format";
const locale = format.formatDefaultLocale({
  decimal: ",",
  thousands: ".",
  grouping: [3],
  currency: ["", "\u00a0€"]
});
Vue.prototype.$fmt = locale.format;

Vue.config.productionTip = false;

var c = Vue.extend(WaffenViz);

var v1 = new c({
  propsData: {
    auswahl: true,
    state: "map1",
    zoom_to: "Waffen & Munition"
  }
});
v1.$mount("#app1");

window.pymChild.sendHeight();

/*
v1.$set(v1, 'auswahl', true);
v1.$set(v1, 'state', 'map1');
v1.$set(v1, 'zoom_to', "Waffen & Munition");
*/
