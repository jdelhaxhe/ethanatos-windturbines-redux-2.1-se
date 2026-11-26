Oui, c'est **tout à fait envisageable** dans Factorio 2.1, **sans avoir besoin de recréer le moindre sprite PNG**, tout en gardant un coût de **0 UPS** sur la physique de placement.

En revanche, passer d'une taille/espacement uniforme (`1.0×` / `18` tuiles) à des paliers différenciés (ex. **`0.75×` / `15`**, **`1.0×` / `20`**, **`1.25×` / `25`**) introduit plusieurs subtilités graphiques, géométriques, ergonomiques et d'équilibrage qu'il faut traiter proprement. Voici l'analyse complète suivie du plan d'implémentation proposé.

---

## 1. Analyse détaillée des enjeux (graphismes, placement, UI, gameplay)

### A. Graphismes, proportions réelles et ancrage des sprites
En mesurant les sprites actuels (`600×800` px en HD à `scale = 1`, soit ~`18.75 × 25` tuiles dont ~`18` tuiles d'envergure de rotor) :
- **Réalisme visuel des pales :**
  - **Mk1 (`0.75×`)** : rotor ≈ `13.5` tuiles → un espacement de **`15` tuiles** laisse ~`1.5` tuile de marge entre pales.
  - **Mk2 (`1.00×`)** : rotor ≈ `18.0` tuiles → un espacement de **`20` tuiles** laisse ~`2.0` tuiles de marge.
  - **Mk3 (`1.25×`)** : rotor ≈ `22.5` tuiles → un espacement de **`25` tuiles** laisse ~`2.5` tuiles de marge (à `18` tuiles comme avant, deux Mk3 à `1.25×` auraient eu des pales qui se traversent).
- **Alignement exact socle / rotor / ombre :**
  - Dans Factorio, le champ `shift` d'un sprite/animation n'est **pas** multiplié automatiquement par `scale`. Pour éviter qu'un Mk1 ne flotte au-dessus de son socle ou qu'un Mk3 ne s'enfonce dans le sol (ou que les pales se décrochent du mât), tous les décalages doivent être multipliés par le facteur d'échelle `s` du tier (`MAIN_OFFSET * s`, `SHADOW_OFFSET * s`, `BLADES_OFFSET * s`, `RENDER_TURBINE_OFFSET * s`, `BLADES_SHADOW_OFFSET * s`, `RENDER_SHADOW_OFFSET * s`).
  - Les animations d'ombre (`ownly_wind_turbine_shadow_0..31`) aujourd'hui partagées doivent être déclinées par tier (`shadow_mk1/2/3_0..31`). Factorio dédupliquant les spritesheets identiques par chemin de fichier, cela représente **0 octet de VRAM supplémentaire**.
- **Qualité d'image (HD & Low-VRAM) :**
  - Mk1 (`0.75×`) sera visuellement **plus net** qu'actuellement.
  - Mk3 (`1.25×`) subit un agrandissement de +25 %, très propre en mode HD, légèrement plus doux en mode `Low VRAM` (`LD`), mais sans dépasser le seuil où la pixelisation devient gênante (éviter de dépasser `1.3×`).
- **Correction du pop-in en bord d'écran :**
  - Une Mk3 à `1.25×` mesure ~`31` tuiles de haut visuellement. En Factorio 2.1, renseigner `drawing_box_vertical_extension` proportionnellement à `s` sur les prototypes `build` et `active` évitera que le mât ne disparaisse brusquement quand son socle sort du bas de l'écran.

---

### B. Le piège critique de l'espacement inter-tiers (et sa solution propre)
Actuellement, le mod repose sur une seule couche de collision (`wt-turbine-spacing`) et une seule boîte invisible `33×33` sous chaque éolienne. **Avec des espacements différents par tier, ce mécanisme simple casserait en cas de mélange de tiers :**
- Si un **Mk1** est posé avec une boîte de `15` tuiles, puis que le joueur pose un **Mk3** à côté, le curseur `build_mk3` (petite tour) ne testerait que la boîte du Mk1 et **autoriserait la pose à 15 tuiles** → les pales du Mk3 traverseraient le Mk1 ! À l'inverse, poser le Mk3 puis le Mk1 bloquerait à `25` tuiles : le jeu serait **asymétrique selon l'ordre de construction**.

**Solution Factorio 2.1 (100 % symétrique, aperçu rouge natif, 0 UPS) :**
- Déclarer **3 couches de collision dédiées** : `wt-spacing-for-mk1`, `wt-spacing-for-mk2`, `wt-spacing-for-mk3`.
- Chaque tour `mkN` (preview + active) porte uniquement la couche `wt-spacing-for-mkN`.
- À la construction d'une éolienne de tier `i`, `control.lua` crée sous elle **1 à 3 boîtes invisibles inertes** (`simple-entity-with-force`), chacune calibrée pour bloquer les tours de tier `j` à la distance exacte `D(i, j)`.
- **Deux règles de distance mixte possibles** (à trancher) :
  1. **Règle physique — Somme des rayons (recommandée)** : chaque tier a un rayon aérodynamique (`7.5` / `10` / `12.5`), donc :
     - `Mk1–Mk1 = 15`, `Mk2–Mk2 = 20`, `Mk3–Mk3 = 25`
     - `Mk1–Mk2 = 18`, `Mk1–Mk3 = 20`, `Mk2–Mk3 = 23`
     *(Cohérent avec la taille réelle des pales : un petit Mk1 peut s'approcher un peu plus d'un Mk3 qu'un autre Mk3).*
  2. **Règle du maximum (`max(Di, Dj)`)** : un Mk3 impose `25` tuiles même à un Mk1 (`Mk1–Mk2 = 20`, `Mk1–Mk3 = 25`, `Mk2–Mk3 = 25`).

*(Dans les deux cas, les tapis, panneaux solaires, pylônes et usines continuent de se construire librement entre les éoliennes.)*

---

### C. Empreinte physique au sol (`collision_box` / `selection_box`) et alignement grille
Dans Factorio, la parité de `ceil(largeur)` impose l'alignement sur la grille : `2×2` (pair) s'aligne sur les intersections (`x.0`), `3×3` (impair) sur les centres de tuiles (`x.5`).
- **Option 1 — Garder une grille 3×3 impaire pour les 3 tiers (recommandée)** :
  - `collision_box` ajustée au socle visuel mais dans `(2.0, 3.0]` : ex. Mk1 `2.1×2.1` (`±1.05`), Mk2 `2.4×2.4` (`±1.2`), Mk3 `2.8×2.8` (`±1.4`), et `selection_box` proportionnelle (`±0.75`, `±0.9`, `±1.15`).
  - **Avantage majeur :** tous les tiers partagent exactement la même grille centrée (`x.5`), les distances entre tiers restent des entiers exacts, et la compatibilité avec les blueprints/grilles existantes reste parfaite.
- **Option 2 — Empreintes 2×2 / 3×3 / 4×4** :
  - Plus différencié physiquement au sol, mais crée un **décalage d'une demi-tuile (`0.5`)** entre Mk1/Mk3 (pairs) et Mk2 (impair), rendant impossible le remplacement au même centre et compliquant l'alignement des blueprints.

---

### D. Ergonomie de placement, UI et limites des blueprints
Avec 3 rayons d'espacement différents, un champ invisible devient frustrant si le joueur doit tâtonner au curseur rouge :
1. **Visualisation dynamique des zones d'exclusion au curseur (fort gain UX) :**
   - Via l'événement `on_player_cursor_stack_changed` (**0 UPS** en jeu normal, exécuté uniquement quand on prend/pose une éolienne en main), afficher un cadre discret (`rendering.draw_rectangle`, visible uniquement pour ce joueur) autour des éoliennes existantes, indiquant la **zone d'exclusion exacte pour le tier tenu en main** (si vous tenez un Mk3, les cadres autour des Mk1 s'agrandissent automatiquement à la distance Mk1–Mk3 !).
   - Activé par défaut, désactivable individuellement via un paramètre `runtime-per-user` (`wt-show-spacing-overlay`).
2. **Tooltips & Factoriopedia :**
   - Ajout d'un champ structuré via `custom_tooltip_fields` (comme déjà fait pour SE dans `lib/utils.lua`) affichant directement l'**espacement minimum** (`15` / `20` / `25` tuiles) sur les items et entités.
3. **Limitation connue des blueprints / fantômes :**
   - Comme dans le mod actuel, les boîtes d'espacement n'existent qu'une fois l'éolienne construite (pas sur un fantôme). Si un joueur superpose manuellement deux fantômes trop proches, les robots construiront le premier puis le second sera bloqué. *(On pourra éventuellement ajouter un avertissement ou bloquer les fantômes qui se chevauchent, ou conserver le comportement standard Factorio.)*

---

### E. Impact gameplay & densité énergétique (point d'équilibrage important)
La surface occupée croît comme le **carré** de l'espacement (`d²`). Avec les puissances actuelles (`750 / 1500 / 3000 kW`) :

| Tier | Avant (`18` tuiles = `324` t²) | Proposé (`15 / 20 / 25`) | Densité (kW / tuile²) | Synergie réseau électrique |
|---|---|---|---|---|
| **Mk1** (`750 kW`) | `2.31 kW/t²` | `15×15` = `225` t² | **`3.33 kW/t²`** *(+44 %)* | 1 sous-station (`18×18`) couvre facilement 4 Mk1 |
| **Mk2** (`1500 kW`) | `4.63 kW/t²` | `20×20` = `400` t² | **`3.75 kW/t²`** *(+12 % vs Mk1)* | Transition sous-stations / grands pylônes |
| **Mk3** (`3000 kW`) | `9.26 kW/t²` | `25×25` = `625` t² | **`4.80 kW/t²`** *(÷2 vs avant)* | Grands pylônes (`32` tuiles de portée) idéaux |

*Remarque :* Contrairement aux panneaux solaires, l'espace entre éoliennes reste constructible, et Mk2/Mk3 divisent fortement le nombre d'entités (UPS + logistique). Toutefois, passer de `18` à `15/20/25` rend le gain de densité du Mk2/Mk3 beaucoup plus progressif — à noter que les puissances (`wt-power-mk1..3`) restent de toute façon modifiables à chaud en `runtime-global`, ou leurs valeurs par défaut peuvent être réajustées si souhaité.

---

### F. Migration de sauvegardes existantes & compatibilité SE / WSC
- **Sauvegardes existantes :** dans `on_configuration_changed`, les anciennes boîtes `ownly_wind_turbine_collision_box_mkN` sont proprement remplacées par les nouvelles boîtes multi-couches. Les fermes déjà construites restent 100 % fonctionnelles sans rien casser (seules les nouvelles poses respecteront les nouveaux espacements).
- **Space Exploration & WindSpeedChanging :** aucun conflit — `prototypes/se_compat.lua` garde son blocage `space_tile` intact, le clonage de vaisseaux SE détruit/recrée les nouvelles boîtes proprement, et `WindSpeedChanging` reste indépendant de l'échelle visuelle.

---

## 2. Plan d'implémentation proposé

1. **Modèle de données (`lib/constants.lua` & `settings.lua`) :**
   - Enrichir `constants.TIERS` avec `visual_scale` (`0.75 / 1.0 / 1.25`), `default_spacing` (`15 / 20 / 25`), `collision_half_size`, `selection_half_size`, `corpse`, et les 3 noms de couches de collision (`wt-spacing-for-mk1..3`).
   - Ajouter des helpers purs pour calculer la matrice de distance symétrique `D(i, j)` et les offsets scalés.
   - Ajouter dans `settings.lua` :
     - *(Optionnel, selon votre choix)* 3 paramètres `startup` d'espacement configurable (`wt-spacing-mk1..3`, défaut `15 / 20 / 25`) + 1 booléen `startup` pour activer/désactiver le dimensionnement réaliste,
     - 1 paramètre `runtime-per-user` (`wt-show-spacing-overlay`, défaut `true`) pour l'affichage des zones d'exclusion au curseur.
2. **Prototypes (`prototypes/collision_layers.lua`, `animations.lua`, `entities.lua`) :**
   - Déclarer les 3 couches `wt-spacing-for-mk1..3`.
   - Décliner les animations de rotors et d'ombres par tier avec `scale * s` et `shift * s` (compatible HD et `Low VRAM`).
   - Générer les boîtes d'espacement par couple `(tier_source, tier_cible)` aux dimensions exactes `D(i, j) - r_j - 0.3`.
   - Mettre à jour `build_preview_entity` et `build_active_entity` (offsets scalés, `drawing_box_vertical_extension`, `selection_box`, `corpse`, et tooltip `custom_tooltip_fields` indiquant l'espacement).
3. **Runtime & Overlay (`lib/turbine_manager.lua` & `control.lua`) :**
   - Adapter `record.collision_box` → `record.collision_boxes` (création, validation, nettoyage, clonage, et migration automatique des anciennes sauvegardes dans `on_configuration_changed`).
   - Adapter `create_renders` pour utiliser les animations d'ombre par tier et les offsets de rendu scalés (`RENDER_TURBINE_OFFSET * s`, `RENDER_SHADOW_OFFSET * s`).
   - Implémenter l'overlay de placement dans un module dédié ou dans `turbine_manager.lua`, piloté par `on_player_cursor_stack_changed` (et nettoyé/rafraîchi à la pose, suppression, changement de surface ou déconnexion).
4. **Localisation & Documentation (`locale/en/base.cfg`, `SPEC.md`, `CHANGELOG.md`, `changelog.txt`, `README.md`) :**
   - Mettre à jour les libellés, descriptions de tooltips, paramètres, la spécification technique (`SPEC.md`) et les changelogs.

---

## Points à valider avant de passer à l'implémentation

Avant de passer en exécution, dites-moi vos préférences sur ces 4 choix :
1. **Règle d'espacement entre tiers différents** (ex. Mk1 à côté d'un Mk3) : **somme des rayons** (`15 / 18 / 20 / 23 / 25`, réaliste) ou **maximum des deux** (`15 / 20 / 25`) ?
2. **Empreinte au sol** : rester en **3×3 impair** pour les 3 tiers (avec boîtes `2.1 / 2.4 / 2.8` pour un alignement grille impeccable) ou passer en **2×2 / 3×3 / 4×4** ?
3. **Paramètres & puissance** : souhaitez-vous que les espacements (`15 / 20 / 25`) soient configurables en `startup` ? Et garde-t-on les puissances par défaut (`750 / 1500 / 3000 kW`) ou souhaitez-vous les rééquilibrer ?
4. **Overlay visuel au curseur** : on l'inclut bien (avec option `runtime-per-user` pour le désactiver) ?

Une fois ces choix confirmés, vous pourrez **toggle to Act mode** pour que je réalise l'implémentation complète.