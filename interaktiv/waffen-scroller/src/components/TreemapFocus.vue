<template>
  <div :class="`TreemapFocus ${this.zoom_to?'zoomed':''} ${this.auswahl?'auswahl':''}`">
    <transition-group tag="div" name="bla" id="treemap_parent">
      <div
        v-for="rd in renderdata"
        class="tmrect"
        :key="rd.id"
        :style="`left: ${rd.x0*100}%;
                top: ${(rd.y0)*100}%;
                width: ${(rd.x1-rd.x0)*100}%;
                height: ${((rd.y1)-(rd.y0))*100}%;
                display: flex;
                justify-content: center;
                align-items: center;
                background-color: ${colorscale(rd.id)};
                `"
                @click="$emit('zoom_to_change', rd.id)"
                >

                <span>
                  <span v-html="`${rd.id}${auswahl && zoom_to || rd.y1-rd.y0>0.24?':':''}`"></span>
                  <br v-if="auswahl && zoom_to || rd.y1-rd.y0>0.24">
                  <span v-if="(auswahl && zoom_to) || rd.y1-rd.y0>0.24" v-html="`${groformat(rd.value)} €`"></span>
                </span>

                <div class="klick" v-if="auswahl && zoom_to" style="position: absolute; top: 5px; left: 5px">…</div>
                <div class="bgthing" :style="`
                                background-image: url('${$base_url ? $base_url : '.'}${`/img/${rd.id}.png`}');
                                background-position: 50% 50%;
                                background-repeat: no-repeat;
                                background-size: contain;`"></div>
      </div>
    </transition-group>
  </div>
</template>

<script>
import data from "../data/exports_sumat.csv";
import { treemap, stratify, treemapBinary } from "d3-hierarchy";

export default {
  name: "TreemapFocus",
  props: {
    zoom_to: String,
    auswahl: Boolean,
    colorscale: Function,
    groformat: Function
  },
  data: () => ({
    renderdata: []
  }),
  watch: {
    zoom_to: function() {
      this.update();
    }
  },
  // computed
  mounted() {
    this.update();
  },
  methods: {
    update: function() {
      var data2 = [{ name: "root", parent: "" }].concat(
        data.map(d => {
          d.parent = "root";
          return d;
        })
      );
      var outerthis = this;
      data2 = data2.filter(
        d =>
          d.name == "root" ||
          (!outerthis.zoom_to || d.name == outerthis.zoom_to)
      );
      var h = stratify()
        .id(d => d.name)
        .parentId(d => d.parent)(data2)
        .sum(d => d.value)
        .sort((a, b) => {
          return a.id == "Andere"
            ? 1
            : b.id == "Andere"
              ? -1
              : b.value - a.value;
        });
      treemap().tile(treemapBinary)(h);

      this.renderdata = h.children;
    }
  }
};
</script>

<style scoped lang="sass">
.TreemapFocus
  transition: width 1s, max-width 1s
  max-width: 100%

  &.auswahl
    cursor: pointer

.TreemapFocus.zoomed
  max-width: 33%
  max-height: 33%

@media(min-width: 520px)
  .TreemapFocus.zoomed
    max-width: 25%
    max-height: 25%

.TreemapFocus.zoomed.auswahl:hover
  transition: opacity 0.5s
  opacity: 0.9

.TreemapFocus.auswahl:hover .tmrect
  transition: opacity 0.5s
  opacity: 0.5

.TreemapFocus.auswahl:hover .tmrect:hover
  transition: opacity 0.5s
  opacity: 1


.tmrect
  position: absolute
  border: 1px solid white
  overflow: hidden

  color: black
  font-weight: bold
  line-height: 1.1em

  .klick
    font-size: 1.5em
    color: rgba(255,255,255,0.5)
    text-shadow: none
    font-weight: normal

  &:hover .klick
    transition: font-size 0.2s, color 0.2s
    font-size: 1.6em
    color: rgba(255,255,255,1)


  & > span
    display: inline-block
    padding: 5px 10px 2px
    background: rgba(255,255,255,0.5)
    text-align: center

  img
    display: block
    max-width: 75%
    max-height: 75%
    position: relative
    margin-left: auto
    margin-right: auto

  .bgthing
    position: absolute
    height: 100%
    width: 100%
    max-height: 500px
    max-width: 500px
    margin-left: auto
    margin-right: auto
    z-index: 1

  span
    z-index: 2


#treemap_parent
  position: relative
  height: 100%


.bla-enter-active, .bla-leave-active
  transition: left 1s, top 1s, width 1s, height 1s

.bla-leave-to
  width: 0 !important
  height: 0 !important
  left: 0 !important
  z-index: -1

@media(max-width:320px)
  .tmrect
    font-size: 10px
</style>
