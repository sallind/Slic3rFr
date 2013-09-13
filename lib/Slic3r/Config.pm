package Slic3r::Config;
use strict;
use warnings;
use utf8;

use List::Util qw(first);

# cemetery of old config settings
our @Ignore = qw(duplicate_x duplicate_y multiply_x multiply_y support_material_tool acceleration
    adjust_overhang_flow);

my $serialize_comma     = sub { join ',', @{$_[0]} };
my $serialize_comma_bool = sub { join ',', map $_ // 0, @{$_[0]} };
my $deserialize_comma   = sub { [ split /,/, $_[0] ] };

our $Options = {

    # miscellaneous options
    'notes' => {
        label   => 'Configuration de notes',
        tooltip => 'Vous pouvez mettre ici vos notes personnelles. Ce texte sera ajouté au code G commentaires d\'en-tête.',
        cli     => 'notes=s',
        type    => 's',
        multiline => 1,
        full_width => 1,
        height  => 130,
        serialize   => sub { join '\n', split /\R/, $_[0] },
        deserialize => sub { join "\n", split /\\n/, $_[0] },
        default => '',
    },
    'threads' => {
        label   => 'Threads',
        tooltip => 'Les threads sont utilisés pour paralléliser les tâches de longue durée. Le nombre de threads optimal est légèrement supérieur au nombre de cœurs / processeurs disponibles. Méfiez-vous que plus de threads consomment plus de mémoire.',
        sidetext => '(more speed but more memory usage)',
        cli     => 'threads|j=i',
        type    => 'i',
        min     => 1,
        max     => 16,
        default => $Slic3r::have_threads ? 2 : 1,
        readonly => !$Slic3r::have_threads,
    },
    'resolution' => {
        label   => 'Résolution',
        tooltip => 'Résolution des détails au minimum, permet de simplifier le fichier d\'entrée pour accélérer le travail de tranchage et réduire la consommation de mémoire. Les modèles à haute résolution ont souvent plus de détail que les imprimantes ne peuvent rendre. Mettre à zéro pour désactiver toute simplification et utiliser la pleine résolution de l\'entrée.',
        sidetext => 'mm',
        cli     => 'resolution=f',
        type    => 'f',
        min     => 0,
        default => 0,
    },

    # output options
    'output_filename_format' => {
        label   => 'Nom de fichier de sortie',
        tooltip => 'Vous pouvez utiliser toutes les options de configuration comme des variables à l\'intérieur de ce modèle. Par exemple: [layer_height], [fill_density], etc Vous pouvez également utiliser [timestamp], [year], [month], [day], [hour], [minute], [second], [version], [input_filename], [input_filename_base].',
        cli     => 'output-filename-format=s',
        type    => 's',
        full_width => 1,
        default => '[input_filename_base].gcode',
    },

    # printer options
    'print_center' => {
        label   => 'Centre d\'impression',
        tooltip => 'Entrez les coordonnées du point G-code que vous voulez centrer votre impression.',
        sidetext => 'mm',
        cli     => 'print-center=s',
        type    => 'point',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [100,100],
    },
    'gcode_flavor' => {
        label   => 'Type de G-code',
        tooltip => 'Certaines commandes G/M-Code, y compris le contrôle de la température et d\'autres, ne sont pas universels. Réglez cette option pour le firmware de votre imprimante pour obtenir une sortie compatible. La type "Pas d\'extrusion" empêche Slic3r d\'exporter toute valeur d\'extrusion.',
        cli     => 'gcode-flavor=s',
        type    => 'select',
        values  => [qw(reprap teacup makerware sailfish mach3 no-extrusion)],
        labels  => ['RepRap (Marlin/Sprinter/Repetier)', 'Teacup', 'MakerWare (MakerBot)', 'Sailfish (MakerBot)', 'Mach3/EMC', 'No extrusion'],
        default => 'reprap',
    },
    'use_relative_e_distances' => {
        label   => 'Utilisation des distacnes relative E',
        tooltip => 'Si votre firmware nécessite des valeurs relatives de E, vérifier, sinon laissez cochée. La plupart des firmwares utilisent des valeurs absolues.',
        cli     => 'use-relative-e-distances!',
        type    => 'bool',
        default => 0,
    },
    'extrusion_axis' => {
        label   => 'Axe d\'extrusion',
        tooltip => 'Utilisez cette option pour définir la lettre de l\'axe associé à votre extrudeuse d\'imprimante (habituellement E mais certaines imprimantes utilisent A).',
        cli     => 'extrusion-axis=s',
        type    => 's',
        default => 'E',
    },
    'z_offset' => {
        label   => 'Offset Z',
        tooltip => 'Cette valeur sera ajouté (ou soustrait) de toutes les coordonnées Z à la sortie du G-code. Il est utilisé pour compenser une mauvaise position de la butée Z: par exemple, si votre zéro de butée se trouve effectivement à 0,3 mm entre la buse et le lit d\'impression, réglez ce paramètre à -0,3 (ou ré-étalonner votre butée).',
        sidetext => 'mm',
        cli     => 'z-offset=f',
        type    => 'f',
        default => 0,
    },
    'gcode_arcs' => {
        label   => 'Utilisation des G-code natif d\'arcs',
        tooltip => 'Cette fonctionnalité expérimentale cherche à détecter des arcs de segments et génère G2/G3 commandes d\'arc au lieu de plusieurs commandes G1 droites.',
        cli     => 'gcode-arcs!',
        type    => 'bool',
        default => 0,
    },
    'g0' => {
        label   => 'Utiliser G0 pour les déplacement de voyage',
        tooltip => 'Activer cette option si votre firmware supporte G0 correctement (découple ainsi tous les axes en utilisant leurs vitesses maximales au lieu de les synchroniser). Mouvements de voyages et rétractations seront combinées dans des commandes simples, ce qui accélère l\'impression vers le haut.',
        cli     => 'g0!',
        type    => 'bool',
        default => 0,
    },
    'gcode_comments' => {
        label   => 'Explicatif de G-code',
        tooltip => 'Activez cette option pour obtenir un fichier G-code commenté, avec chaque ligne expliquée par un texte descriptif. Si vous imprimez depuis une carte SD, la taille supplémentaire du fichier pourrait ralentir votre firmware.',
        cli     => 'gcode-comments!',
        type    => 'bool',
        default => 0,
    },
    
    # extruders options
    'extruder_offset' => {
        label   => 'Offset d\'extrudeur',
        tooltip => 'Si votre firmware ne gére pas le déplacement de l\'extrudeuse vous avez besoin du G-code pour en tenir compte. Cette option vous permet de spécifier le déplacement de chaque extrudeuse par rapport à la première. Il s\'attend coordonnées positive (ils seront soustraits de coordonnées XY).',
        sidetext => 'mm',
        cli     => 'extruder-offset=s@',
        type    => 'point',
        serialize   => sub { join ',', map { join 'x', @$_ } @{$_[0]} },
        deserialize => sub { [ map [ split /x/, $_ ], (ref $_[0] eq 'ARRAY') ? @{$_[0]} : (split /,/, $_[0] || '0x0') ] },
        default => [[0,0]],
    },
    'nozzle_diameter' => {
        label   => 'Diamèter de buse',
        tooltip => 'C\'est le diamètre de votre buse d\'extrusion (par exemple: 0.5, 0.35, etc)',
        cli     => 'nozzle-diameter=f@',
        type    => 'f',
        sidetext => 'mm',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [0.5],
    },
    'filament_diameter' => {
        label   => 'Diamèter',
        tooltip => 'Entrez votre diamètre de fil ici. Une bonne précision est nécessaire, utiliser un pied à coulisse et faire plusieurs mesures le long du fil, puis calculer la moyenne.',
        sidetext => 'mm',
        cli     => 'filament-diameter=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default     => [3],
    },
    'extrusion_multiplier' => {
        label   => 'Multiplicateur dextrusion',
        tooltip => 'Ce facteur modifie la quantité de débit proportionnelle. Vous devrez peut-être modifier ce paramètre pour obtenir une belle finition de surface et de corriger les largeurs de paroi simple. Les valeurs habituelles se situent entre 0,9 et 1,1. Si vous pensez que vous devez modifier plus, consultez le diamètre du fil et vos paramètres firmware E.',
        cli     => 'extrusion-multiplier=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [1],
    },
    'temperature' => {
        label   => 'Autre couche',
        tooltip => 'Température d\'extrusion pour les couches après la première. Mettre ce paramètre à zéro pour désactiver les commandes de contrôle de la température dans la sortie.',
        sidetext => '°C',
        cli     => 'temperature=i@',
        type    => 'i',
        max     => 400,
        serialize   => $serialize_comma,
        deserialize => sub { $_[0] ? [ split /,/, $_[0] ] : [0] },
        default => [200],
    },
    'first_layer_temperature' => {
        label   => 'Première couche',
        tooltip => 'Température de l\'extrudeuse pour la première couche. Si vous voulez contrôler la température manuellement lors de l\'impression, mettre ce paramètre à zéro pour désactiver les commandes de contrôle de la température dans le fichier de sortie.',
        sidetext => '°C',
        cli     => 'first-layer-temperature=i@',
        type    => 'i',
        serialize   => $serialize_comma,
        deserialize => sub { $_[0] ? [ split /,/, $_[0] ] : [0] },
        max     => 400,
        default => [200],
    },
    
    # extruder mapping
    'perimeter_extruder' => {
        label   => 'Extrudeur de périmètre',
        tooltip => 'L\'extrudeuse à utiliser lors de l\'impression du périmètres.',
        cli     => 'perimeter-extruder=i',
        type    => 'i',
        aliases => [qw(perimeters_extruder)],
        default => 1,
    },
    'infill_extruder' => {
        label   => 'Extrudeur de remplissage',
        tooltip => 'L\'extrudeuse à utiliser lors de l\'impression de remplissage.',
        cli     => 'infill-extruder=i',
        type    => 'i',
        default => 1,
    },
    'support_material_extruder' => {
        label   => 'Extrudeur de support de matériaux',
        tooltip => 'L\'extrudeuse à utiliser lors de l\'impression de matières de support. Cela affecte bord et le radeau.',
        cli     => 'support-material-extruder=i',
        type    => 'i',
        default => 1,
    },
    'support_material_interface_extruder' => {
        label   => 'Extrudeur d\'interface de support de matériaux',
        tooltip => 'L\'extrudeuse à utiliser lors de l\'impression de l\'interface matériau de support. Cela affecte aussi radeau.',
        cli     => 'support-material-interface-extruder=i',
        type    => 'i',
        default => 1,
    },
    
    # filament options
    'first_layer_bed_temperature' => {
        label   => 'Première couche',
        tooltip => 'Température de la plaque pour la première couche. Mettre ce paramètre à zéro pour désactiver les commandes de contrôle de la température du Lit d\'impression dans la sortie.',
        sidetext => '°C',
        cli     => 'first-layer-bed-temperature=i',
        type    => 'i',
        max     => 300,
        default => 0,
    },
    'bed_temperature' => {
        label   => 'Autre couche',
        tooltip => 'Température du Lit d\'impression après la première couche. Mettre ce paramètre à zéro pour désactiver les commandes de contrôle de la température du Lit d\'impression dans la sortie.',
        sidetext => '°C',
        cli     => 'bed-temperature=i',
        type    => 'i',
        max     => 300,
        default => 0,
    },
    
    # speed options
    'travel_speed' => {
        label   => 'Voyage',
        tooltip => 'Vitesse pour des mouvements de voyage (sauts entre les points d\'extrusion éloignés).',
        sidetext => 'mm/s',
        cli     => 'travel-speed=f',
        type    => 'f',
        aliases => [qw(travel_feed_rate)],
        default => 130,
    },
    'perimeter_speed' => {
        label   => 'Périmèters',
        tooltip => 'Vitesse de périmètres (contours, des coquilles verticales).',
        sidetext => 'mm/s',
        cli     => 'perimeter-speed=f',
        type    => 'f',
        aliases => [qw(perimeter_feed_rate)],
        default => 30,
    },
    'small_perimeter_speed' => {
        label   => 'Petit périmètres',
        tooltip => 'Ce réglage séparé aura une incidence sur la vitesse de périmètres ayant un rayon <= 6,5 mm (habituellement des trous). Si elle est exprimée en pourcentage (par exemple: 80%), il sera calculé sur la vitesse de périmètres ci-dessus.',
        sidetext => 'mm/s or %',
        cli     => 'small-perimeter-speed=s',
        type    => 'f',
        ratio_over => 'perimeter_speed',
        default => 30,
    },
    'external_perimeter_speed' => {
        label   => 'Périmètre externe',
        tooltip => 'Ce réglage aura une incidence sur la vitesse de périmètres extérieurs (ceux qui sont visibles). Si elle est exprimée en pourcentage (par exemple: 80%), il sera calculé sur la vitesse de périmètres ci-dessus.',
        sidetext => 'mm/s or %',
        cli     => 'external-perimeter-speed=s',
        type    => 'f',
        ratio_over => 'perimeter_speed',
        default => '70%',
    },
    'infill_speed' => {
        label   => 'Remplissage',
        tooltip => 'Vitesse d\'impression du remplissage intérieur.',
        sidetext => 'mm/s',
        cli     => 'infill-speed=f',
        type    => 'f',
        aliases => [qw(print_feed_rate infill_feed_rate)],
        default => 60,
    },
    'solid_infill_speed' => {
        label   => 'Remplissage solide',
        tooltip => 'Vitesse d\'impression des régions solides (haut / bas / interne coquilles horizontales). Cela peut être exprimée en pourcentage (par exemple: 80%) sur la vitesse de remplissage par défaut ci-dessus.',
        sidetext => 'mm/s or %',
        cli     => 'solid-infill-speed=s',
        type    => 'f',
        ratio_over => 'infill_speed',
        aliases => [qw(solid_infill_feed_rate)],
        default => 60,
    },
    'top_solid_infill_speed' => {
        label   => 'Premières régions solides',
        tooltip => 'Vitesse d\'impression premières régions solides. Vous voudrez peut-être ralentir pour obtenir un fini de surface plus agréable. Cela peut être exprimée en pourcentage (par exemple: 80%) sur la vitesse de remplissage solide ci-dessus.',
        sidetext => 'mm/s or %',
        cli     => 'top-solid-infill-speed=s',
        type    => 'f',
        ratio_over => 'solid_infill_speed',
        default => 50,
    },
    'support_material_speed' => {
        label   => 'Matériaux de support',
        tooltip => 'Vitesse de matériau support d\'impression.',
        sidetext => 'mm/s',
        cli     => 'support-material-speed=f',
        type    => 'f',
        default => 60,
    },
    'bridge_speed' => {
        label   => 'Pont',
        tooltip => 'Vitesse d\'impression pour les ponts.',
        sidetext => 'mm/s',
        cli     => 'bridge-speed=f',
        type    => 'f',
        aliases => [qw(bridge_feed_rate)],
        default => 60,
    },
    'gap_fill_speed' => {
        label   => 'Remplissage de petits écarts',
        tooltip => 'Vitesse de remplissage de petits écarts à l\'aide de courts déplacements en zigzag. Conservez ce niveau raisonnablement bas pour éviter trop de secousses et les questions de résonance. Régler zéro pour désactiver.',
        sidetext => 'mm/s',
        cli     => 'gap-fill-speed=f',
        type    => 'f',
        default => 20,
    },
    'first_layer_speed' => {
        label   => 'Vitesse de première couche',
        tooltip => 'Si elle est exprimée en valeur absolue en mm/s, cette vitesse sera appliquée à tous les impression de déplacement de la première couche, indépendamment de leur type. Si, exprimée en pourcentage (par exemple: 40%), il met à l\'échelle les vitesses par défaut.',
        sidetext => 'mm/s or %',
        cli     => 'first-layer-speed=s',
        type    => 'f',
        default => '30%',
    },
    
    # acceleration options
    'default_acceleration' => {
        label   => 'Défaut',
        tooltip => 'C\'est l\'accélération de votre imprimante generale, les valeurs d\'accélération spécifiques sont utilisés (périmètre / remplissage). Régler zéro pour empêcher la réinitialisation de l\'accélération.',
        sidetext => 'mm/s²',
        cli     => 'default-acceleration=f',
        type    => 'f',
        default => 0,
    },
    'perimeter_acceleration' => {
        label   => 'Périmèters',
        tooltip => 'C\'est l\'accélération de votre imprimante pour les périmètres. Une valeur élevée comme 9000 donne généralement de bons résultats si votre matériel est à la hauteur. Régler zéro pour désactiver le contrôle d\'accélération pour les périmètres.',
        sidetext => 'mm/s²',
        cli     => 'perimeter-acceleration=f',
        type    => 'f',
        default => 0,
    },
    'infill_acceleration' => {
        label   => 'Remplissage',
        tooltip => 'C\'est l\'accélération de votre imprimante pour les remplissage. Régler zéro pour désactiver le contrôle d\'accélération pour le remplissage.',
        sidetext => 'mm/s²',
        cli     => 'infill-acceleration=f',
        type    => 'f',
        default => 0,
    },
    'bridge_acceleration' => {
        label   => 'Pont',
        tooltip => 'C\'est l\'accélération de votre imprimante pour les ponts. Régler zéro pour désactiver le contrôle d\'accélération pour les ponts.',
        sidetext => 'mm/s²',
        cli     => 'bridge-acceleration=f',
        type    => 'f',
        default => 0,
    },
    'first_layer_acceleration' => {
        label   => 'Première couche',
        tooltip => 'C\'est l\'accélération de votre imprimante pour la première couche. Régler zéro pour désactiver le contrôle d\'accélération pour la première couche.',
        sidetext => 'mm/s²',
        cli     => 'first-layer-acceleration=f',
        type    => 'f',
        default => 0,
    },
    
    # accuracy options
    'layer_height' => {
        label   => 'Hauteur de couche',
        tooltip => 'Ce paramètre contrôle la hauteur (et donc le nombre total) des tranches/couches. Les couches minces donnent une meilleure précision, mais prennent plus de temps à imprimer.',
        sidetext => 'mm',
        cli     => 'layer-height=f',
        type    => 'f',
        default => 0.4,
    },
    'first_layer_height' => {
        label   => 'Hauteur de la première couche',
        tooltip => 'Lors de l\'impression avec des hauteurs de couche très faibles, vous pouvez toujours vouloir imprimer une couche inférieure plus épaisse pour améliorer l\'adhérence et la tolérance pour les plaques non parfaites. Ceci peut être exprimé en valeur absolue, soit en pourcentage (par exemple: 150%) sur la hauteur de la couche par défaut.',
        sidetext => 'mm or %',
        cli     => 'first-layer-height=s',
        type    => 'f',
        ratio_over => 'layer_height',
        default => 0.35,
    },
    'infill_every_layers' => {
        label   => 'Combiner toutes le coucheintermédiaire',
        full_label   => 'Combiner les couche tout les',
        tooltip => 'Cette fonction permet de combiner le remplissage et accélérer votre impression par extrusion de couches épaisses tout en préservant un périmètres minces, donc la précision.',
        sidetext => 'layers',
        scope   => 'object',
        category => 'Infill',
        cli     => 'infill-every-layers=i',
        type    => 'i',
        min     => 1,
        default => 1,
    },
    'solid_infill_every_layers' => {
        label   => 'Couche solide toutes les',
        tooltip => 'Cette fonction permet de forcer une couche solide à chaque nombre donné de couches. Zéro pour désactiver.',
        sidetext => 'layers',
        scope   => 'object',
        category => 'Infill',
        cli     => 'solid-infill-every-layers=i',
        type    => 'i',
        min     => 0,
        default => 0,
    },
    'infill_only_where_needed' => {
        label   => 'Remplissage inter si besoin',
        tooltip => 'Cette option permet de limiter le remplissage pour les zones réellement nécessaires pour soutenir les plafonds (il agira comme support interne).',
        scope   => 'object',
        category => 'Infill',
        cli     => 'infill-only-where-needed!',
        type    => 'bool',
        default => 0,
    },
    'infill_first' => {
        label   => 'Périmètres ou remplissage en premier',
        tooltip => 'Cette option permet de changer l\'ordre d\'impression des périmètres et remplissage, ce qui rend celui-ci en premier.',
        cli     => 'infill-first!',
        type    => 'bool',
        default => 0,
    },
    
    # flow options
    'extrusion_width' => {
        label   => 'Valeur par défaut d\'extrusion',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel. Si elle reste à zéro, Slic3r calcule automatiquement la largeur. Si elle est exprimée en pourcentage (par exemple: 230%), il sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for auto)',
        cli     => 'extrusion-width=s',
        type    => 'f',
        default => 0,
    },
    'first_layer_extrusion_width' => {
        label   => 'Première couche',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel pour la première couche. Vous pouvez l\'utiliser pour forcer une extrusion plus grose pour une meilleure adhérence. Si elle est exprimée en pourcentage (par exemple 120%) si sera calculée sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'first-layer-extrusion-width=s',
        type    => 'f',
        default => '200%',
    },
    'perimeter_extrusion_width' => {
        label   => 'Périmèters',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel pour périmètres. Vous pouvez utiliser une valeur petite pour obtenir des surfaces plus précise. Si, exprimée en pourcentage (par exemple 90%) dans le cas sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'perimeter-extrusion-width=s',
        type    => 'f',
        aliases => [qw(perimeters_extrusion_width)],
        default => 0,
    },
    'infill_extrusion_width' => {
        label   => 'Remplissage',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel de remplissage. Vous pouvez utiliser extrudés plus gros afin d\'accélérer le remplissage et rendre vos parties plus forte. Si, exprimée en pourcentage (par exemple 90%) dans le cas sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'infill-extrusion-width=s',
        type    => 'f',
        default => 0,
    },
    'solid_infill_extrusion_width' => {
        label   => 'Remplissage solide',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel de remplissage pour les surfaces solides. Si, exprimée en pourcentage (par exemple 90%) dans le cas sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'solid-infill-extrusion-width=s',
        type    => 'f',
        default => 0,
    },
    'top_infill_extrusion_width' => {
        label   => 'Remplissage de fin',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel de remplissage pour les surfaces supérieures. Vous pouvez utiliser extrudés minces pour remplir toutes les régions étroites et obtenir une finition lisse. Si, exprimée en pourcentage (par exemple 90%) dans le cas sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'top-infill-extrusion-width=s',
        type    => 'f',
        default => 0,
    },
    'support_material_extrusion_width' => {
        label   => 'Support de matériaux',
        tooltip => 'Réglez-le sur une valeur non nulle pour définir une largeur d\'extrusion manuel de matériel d\'appui. Si, exprimée en pourcentage (par exemple 90%) dans le cas sera calculé sur la hauteur de la couche.',
        sidetext => 'mm or % (leave 0 for default)',
        cli     => 'support-material-extrusion-width=s',
        type    => 'f',
        default => 0,
    },
    'bridge_flow_ratio' => {
        label   => 'Rapport de flux pour pont',
        tooltip => 'Ce facteur influe sur la quantité de plastique pour le pontage. Vous pouvez diminuer légèrement pour retirer les extrudés et éviter l\'affaissement, même si les paramètres par défaut sont généralement bon, vous devez essayer de refroidir (utiliser un ventilateur) avant de peaufiner cela.',
        cli     => 'bridge-flow-ratio=f',
        type    => 'f',
        default => 1,
    },
    'vibration_limit' => {
        label   => 'Fréquence limite',
        tooltip => 'Cette option expérimentale permet de ralentir les mouvements et d\'atteindre la limite de fréquence configurée. L\'objectif de réduire les vibrations est d\'éviter la résonance mécanique. Régler zéro pour désactiver.',
        sidetext => 'Hz',
        cli     => 'vibration-limit=f',
        type    => 'f',
        default => 0,
    },
    
    # print options
    'perimeters' => {
        label   => 'Périmèters (minimum)',
        tooltip => 'Cette option définit le nombre de périmètres à générer pour chaque couche. Notez que Slic3r peut augmenter ce nombre automatiquement lorsqu\'il détecte des surfaces inclinées et qui bénéficient d\'un plus grand nombre de périmètres si l\'option périmètres supplémentaire est activé.',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'perimeters=i',
        type    => 'i',
        aliases => [qw(perimeter_offsets)],
        default => 3,
    },
    'solid_layers' => {
        label   => 'Couche solide',
        tooltip => 'Nombre de couches solides pour produire les surfaces supérieure et inférieure.',
        cli     => 'solid-layers=i',
        type    => 'i',
        shortcut => [qw(top_solid_layers bottom_solid_layers)],
    },
    'top_solid_layers' => {
        label   => 'Haut',
        full_label => 'Couche solide du haut',
        tooltip => 'Nombre de couches solides pour générer les surfaces supérieures.',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'top-solid-layers=i',
        type    => 'i',
        default => 3,
    },
    'bottom_solid_layers' => {
        label   => 'Bas',
        full_label => 'Couche solide du bas',
        tooltip => 'Nombre de couches solides pour générer des surfaces inférieurs.',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'bottom-solid-layers=i',
        type    => 'i',
        default => 3,
    },
    'fill_pattern' => {
        label   => 'Modèle de remplissage',
        tooltip => ';odèle de remplissage général de faible densité.',
        scope   => 'object',
        category => 'Infill',
        cli     => 'fill-pattern=s',
        type    => 'select',
        values  => [qw(rectilinear line concentric honeycomb hilbertcurve archimedeanchords octagramspiral)],
        labels  => [qw(rectilinear line concentric honeycomb), 'hilbertcurve (slow)', 'archimedeanchords (slow)', 'octagramspiral (slow)'],
        default => 'honeycomb',
    },
    'solid_fill_pattern' => {
        label   => 'Modèle de remplissage haut / bas.',
        tooltip => 'Modèle de remplissage haut / bas.',
        scope   => 'object',
        category => 'Infill',
        cli     => 'solid-fill-pattern=s',
        type    => 'select',
        values  => [qw(rectilinear concentric hilbertcurve archimedeanchords octagramspiral)],
        labels  => [qw(rectilinear concentric), 'hilbertcurve (slow)', 'archimedeanchords (slow)', 'octagramspiral (slow)'],
        default => 'rectilinear',
    },
    'fill_density' => {
        label   => 'Densité de remplissage',
        tooltip => 'La densité de remplissage interne, exprimé dans l\'intervalle 0 - 1.',
        scope   => 'object',
        category => 'Infill',
        cli     => 'fill-density=f',
        type    => 'f',
        default => 0.4,
    },
    'fill_angle' => {
        label   => 'Angle de remplissage',
        tooltip => 'Angle de base par défaut pour une orientation de remplissage. Hachures sera appliqué à ce sujet. Ponts seront comblées en utilisant la meilleure direction Slic3r peut détecter, donc ce paramètre ne les affecte pas.',
        sidetext => '°',
        cli     => 'fill-angle=i',
        type    => 'i',
        max     => 359,
        default => 45,
    },
    'solid_infill_below_area' => {
        label   => 'Superficie de remplicage mini',
        tooltip => 'Forcer remplissage solide pour les régions ayant une superficie inférieure au seuil spécifié.',
        sidetext => 'mm²',
        scope   => 'object',
        category => 'Infill',
        cli     => 'solid-infill-below-area=f',
        type    => 'f',
        default => 70,
    },
    'extra_perimeters' => {
        label   => 'Périmètre supplémentaire',
        tooltip => 'Ajouter plus de périmètres lorsque cela est nécessaire pour éviter les lacunes dans les murs en pente.',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'extra-perimeters!',
        type    => 'bool',
        default => 1,
    },
    'randomize_start' => {
        label   => 'Depart de point aléatoire',
        tooltip => 'Commencez chaque couche d\'un autre sommet pour empêcher l\'accumulation de plastique sur le même coin.',
        cli     => 'randomize-start!',
        type    => 'bool',
        default => 0,
    },
    'start_perimeters_at_concave_points' => {
        label   => 'Points concave',
        tooltip => 'Préfèrent commencer les périmètres à un point concave.',
        cli     => 'start-perimeters-at-concave-points!',
        type    => 'bool',
        default => 0,
    },
    'start_perimeters_at_non_overhang' => {
        label   => 'Point en surplomb',
        tooltip => 'Préfèrent commencer périmètres à des points non en surplomb.',
        cli     => 'start-perimeters-at-non-overhang!',
        type    => 'bool',
        default => 0,
    },
    'thin_walls' => {
        label   => 'Detection de mur fin',
        tooltip => 'Détecter les murs de largeur simple (pièces à deux extrusions ou ajustement que nous devons les réduire en une seule trace).',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'thin-walls!',
        type    => 'bool',
        default => 1,
    },
    'overhangs' => {
        label   => 'Detection de surplombs',
        tooltip => 'Option expérimentale pour ajuster le débit de surplombs (flux pont sera utilisé), d\'appliquer la vitesse de pont pour eux et permettre la ventillation.',
        scope   => 'object',
        category => 'Layers and Perimeters',
        cli     => 'overhangs!',
        type    => 'bool',
        default => 1,
    },
    'avoid_crossing_perimeters' => {
        label   => 'Évitez de croiser les périmètres',
        tooltip => 'Optimiser les déplacements de voyage afin de minimiser la traversée des périmètres. C\'est surtout utile avec extrudeuses Bowden qui souffrent de suintement. Cette fonction ralentit la génération G-code.',
        cli     => 'avoid-crossing-perimeters!',
        type    => 'bool',
        default => 0,
    },
    'external_perimeters_first' => {
        label   => 'Impression des périmètre éloigné',
        tooltip => 'Imprimer le périmètres de contour de la plus loin à la plus au centre au lieu de l\'ordre inverse par défaut.',
        cli     => 'external-perimeters-first!',
        type    => 'bool',
        default => 0,
    },
    'spiral_vase' => {
        label   => 'Vase spirale',
        tooltip => 'Cette fonctionnalité expérimentale va augmenter progressivement Z pendant l\'impression d\'un objet à paroi simple afin d\'éliminer toute couture visible. En activant cette option les autres paramètres seront remplacés à un seul périmètre, aucun remplissage, pas de couches massif, aucun matériau de support. Vous pouvez toujours définir un certain nombre de couches solides de fond ainsi que des boucles de jupe / de bord. Ilne mrche pas lors de l\'impression de plus d\'un objet.',
        cli     => 'spiral-vase!',
        type    => 'bool',
        default => 0,
    },
    'only_retract_when_crossing_perimeters' => {
        label   => 'Rétracter seulement lors de la traversée des périmètres',
        tooltip => 'Désactive la rétractation lorsque la trajectoire de déplacement ne dépasse pas la couche supérieure de périmètres (et donc n \'importe quel vase sera probablement invisible).',
        cli     => 'only-retract-when-crossing-perimeters!',
        type    => 'bool',
        default => 1,
    },
    'support_material' => {
        label   => 'Produire du matériel de soutien',
        scope   => 'object',
        category => 'Support material',
        tooltip => 'Activer la génération de matériel d\'appui.',
        cli     => 'support-material!',
        type    => 'bool',
        default => 0,
    },
    'support_material_threshold' => {
        label   => 'Support d\'apuis pour les surpomb',
        tooltip => 'Le matériel d\'appui ne sera pas généré pour surplombs dont l\'angle d\'inclinaison est supérieur au seuil donné. Mis à zéro pour la détection automatique.',
        sidetext => '°',
        scope   => 'object',
        category => 'Support material',
        cli     => 'support-material-threshold=i',
        type    => 'i',
        default => 0,
    },
    'support_material_pattern' => {
        label   => 'Motif',
        tooltip => 'Motif utilisé pour générer matériau de support.',
        scope   => 'object',
        category => 'Support material',
        cli     => 'support-material-pattern=s',
        type    => 'select',
        values  => [qw(rectilinear rectilinear-grid honeycomb)],
        labels  => ['rectilinear', 'rectilinear grid', 'honeycomb'],
        default => 'honeycomb',
    },
    'support_material_spacing' => {
        label   => 'Espacement de soutien matériel.',
        tooltip => 'L\'espacement entre les lignes de soutien matériel.',
        sidetext => 'mm',
        scope   => 'object',
        category => 'Support material',
        cli     => 'support-material-spacing=f',
        type    => 'f',
        default => 2.5,
    },
    'support_material_angle' => {
        label   => 'angle de soutien matériel',
        tooltip => 'Utilisez ce paramètre pour faire pivoter le motif du matériel d\'appui sur le plan horizontal.',
        scope   => 'object',
        category => 'Support material',
        sidetext => '°',
        cli     => 'support-material-angle=i',
        type    => 'i',
        default => 0,
    },
    'support_material_interface_layers' => {
        label   => 'Couche d\'interface',
        tooltip => 'Nombre de couches d\'interface à insérer entre l\'objet (s) et la matière de support.',
        sidetext => 'layers',
        scope   => 'object',
        category => 'Support material',
        cli     => 'support-material-interface-layers=i',
        type    => 'i',
        default => 3,
    },
    'support_material_interface_spacing' => {
        label   => 'Espace d\'interface',
        tooltip => 'L\'espacement entre les lignes d\'interface. Régler zéro pour obtenir une interface solide.',
        scope   => 'object',
        category => 'Support material',
        sidetext => 'mm',
        cli     => 'support-material-interface-spacing=f',
        type    => 'f',
        default => 0,
    },
    'support_material_enforce_layers' => {
        label   => 'Appliquer un soutien pour la première',
        full_label   => 'Appliquer un soutien pour les n premières couches ',
        tooltip => 'Produire du matériel de soutien pour le nombre spécifié de couches à compter du fond, indépendamment du fait que la documentation d\'appui normale est activée ou non et indépendamment de tout seuil d\'angle. Ceci est utile pour obtenir plus d\'adhérence des objets ayant une empreinte très fine ou pauvres sur la plaque de construction.',
        sidetext => 'layers',
        scope   => 'object',
        category => 'Support material',
        cli     => 'support-material-enforce-layers=f',
        type    => 'i',
        default => 0,
    },
    'raft_layers' => {
        label   => 'Couches de base',
        tooltip => 'L\'objet sera soulevé par ce nombre de couches et matériel d\'appui en dessous.',
        sidetext => 'layers',
        scope   => 'object',
        category => 'Support material',
        cli     => 'raft-layers=i',
        type    => 'i',
        default => 0,
    },
    'start_gcode' => {
        label   => 'G-code de debut',
        tooltip => 'Cette procédure de démarrage est inséré au début du fichier de sortie, juste après les instructions de commande de température pour extrudeuse et le Lit d\'impression. Si Slic3r détecte M104 ou M190 dans vos codes personnalisés, ces commandes ne seront pas déterminé automatiquement. Notez que vous pouvez utiliser des variables d\'espace réservé pour tous les paramètres de Slic3r, de sorte que vous pouvez mettre une commande "M104 S [first_layer_temperature]" où vous voulez.',
        cli     => 'start-gcode=s',
        type    => 's',
        multiline => 1,
        full_width => 1,
        height  => 120,
        serialize   => sub { join '\n', split /\R+/, $_[0] },
        deserialize => sub { join "\n", split /\\n/, $_[0] },
        default => <<'END',
G28 ; home all axes
G1 Z5 F5000 ; lift nozzle
END
    },
    'end_gcode' => {
        label   => 'G-code de fin',
        tooltip => 'Cette procédure d\'extrémité est insérée à la fin du fichier de sortie. Notez que vous pouvez utiliser des variables d\'espace réservé pour tous les paramètres de Slic3r.',
        cli     => 'end-gcode=s',
        type    => 's',
        multiline => 1,
        full_width => 1,
        height  => 120,
        serialize   => sub { join '\n', split /\R+/, $_[0] },
        deserialize => sub { join "\n", split /\\n/, $_[0] },
        default => <<'END',
M104 S0 ; turn off temperature
G28 X0  ; home X axis
M84     ; disable motors
END
    },
    'layer_gcode' => {
        label   => 'G-code de changement de couche',
        tooltip => 'Ce code personnalisé est inséré à chaque changement de couche, juste après le déplacement de Z et avant que l\'extrudeuse se déplace vers le premier point de la couche. Notez que vous pouvez utiliser des variables d\'espace réservé pour tous les paramètres de Slic3r.',
        cli     => 'layer-gcode=s',
        type    => 's',
        multiline => 1,
        full_width => 1,
        height  => 50,
        serialize   => sub { join '\n', split /\R+/, $_[0] },
        deserialize => sub { join "\n", split /\\n/, $_[0] },
        default => '',
    },
    'toolchange_gcode' => {
        label   => 'G-code de changement de tête',
        tooltip => 'Ce code personnalisé est inséré à chaque changement d\'extrudeuse. Notez que vous pouvez utiliser des variables d\'espace réservé pour tous les paramètres de Slic3r ainsi que [previous_extruder] et [next_extruder].',
        cli     => 'toolchange-gcode=s',
        type    => 's',
        multiline => 1,
        full_width => 1,
        height  => 50,
        serialize   => sub { join '\n', split /\R+/, $_[0] },
        deserialize => sub { join "\n", split /\\n/, $_[0] },
        default => '',
    },
    'post_process' => {
        label   => 'Scripts de post-traitement',
        tooltip => 'Si vous voulez traiter la sortie du G-code par le biais de scripts personnalisés, ajouter uniquement la liste de leurs chemins absolus ici. Plusieurs scripts séparés par un point virgule. Les chemin absolu des scripts seront transmis vers le fichier G-code comme argument, et ils peuvent accéder aux paramètres de configuration Slic3r en lisant les variables d\'environnement.',
        cli     => 'post-process=s@',
        type    => 's@',
        multiline => 1,
        full_width => 1,
        height  => 60,
        serialize   => sub { join '; ', @{$_[0]} },
        deserialize => sub { [ split /\s*(?:;|\R)\s*/s, $_[0] ] },
        default => [],
    },
    
    # retraction options
    'retract_length' => {
        label   => 'Longueur',
        tooltip => 'Lorsque la rétraction est déclenchée, le filament est tiré vers l\'arrière de la quantité spécifiée (la longueur est mesurée à filament brut, avant qu\'il n\'entre dans l\'extrudeuse).',
        sidetext => 'mm (zero to disable)',
        cli     => 'retract-length=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [1],
    },
    'retract_speed' => {
        label   => 'Vitesse',
        tooltip => 'La vitesse de rétraction (elle s\'applique seulement au moteur d\'extrudeuse).',
        sidetext => 'mm/s',
        cli     => 'retract-speed=f@',
        type    => 'i',
        max     => 1000,
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [30],
    },
    'retract_restart_extra' => {
        label   => 'Longueur supplémentaire au redémarrage',
        tooltip => 'Lorsque le retrait est compensé après le déménagement de voyage, l\'extrudeuse va pousser cette valeur de fil supplémentaire. Ce paramètre est rarement nécessaire.',
        sidetext => 'mm',
        cli     => 'retract-restart-extra=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [0],
    },
    'retract_before_travel' => {
        label   => 'Voyage minimum après la rétraction',
        tooltip => 'La rétraction n\'est pas déclenchée lors du déplacement de voyages qui sont plus courts que cette longueur.',
        sidetext => 'mm',
        cli     => 'retract-before-travel=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [2],
    },
    'retract_lift' => {
        label   => 'Soulever Z',
        tooltip => 'Si vous réglez ce paramètre sur une valeur positive, Z est rapidement soulevé à chaque fois qu\'une rétraction est déclenchée. Lorsque vous utilisez plusieurs extrudeuses, seul le réglage pour la première extrudeuse sera considérée.',
        sidetext => 'mm',
        cli     => 'retract-lift=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [0],
    },
    'retract_layer_change' => {
        label   => 'Rétraction sur le changement de couche',
        tooltip => 'Ce paramètre impose une rétraction chaque fois qu\'un mouvement Z est fait.',
        cli     => 'retract-layer-change!',
        type    => 'bool',
        serialize   => $serialize_comma_bool,
        deserialize => $deserialize_comma,
        default => [1],
    },
    'wipe' => {
        label   => 'Essuyer tout en rétractant',
        tooltip => 'Cet indicateur déplace la buse tout en rétractant sert à minimiser le blob possible sur des extrudeuses qui fuient.',
        cli     => 'wipe!',
        type    => 'bool',
        serialize   => $serialize_comma_bool,
        deserialize => $deserialize_comma,
        default => [0],
    },
    'retract_length_toolchange' => {
        label   => 'Longueur',
        tooltip => 'Lorsque la rétraction est déclenchée avant le changement d\'outil, le fil est tiré vers l\'arrière de la quantité spécifiée (la longueur est mesurée à filament brut, avant qu\'il n\'entre dans l\'extrudeuse).',
        sidetext => 'mm (zero to disable)',
        cli     => 'retract-length-toolchange=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [10],
    },
    'retract_restart_extra_toolchange' => {
        label   => 'Longueur supplémentaire au redémarrage',
        tooltip => 'Lorsque le retrait est compensé après le changement d\'outil, l\'extrudeuse va pousser cette valeurs supplémentaire de fil.',
        sidetext => 'mm',
        cli     => 'retract-restart-extra-toolchange=f@',
        type    => 'f',
        serialize   => $serialize_comma,
        deserialize => $deserialize_comma,
        default => [0],
    },
    
    # cooling options
    'cooling' => {
        label   => 'Activer le refroidissement automatique',
        tooltip => 'Cet indicateur permet la logique de refroidissement automatique qui ajuste la vitesse d\'impression et la vitesse du ventilateur en fonction du temps d\'impression de la couche.',
        cli     => 'cooling!',
        type    => 'bool',
        default => 1,
    },
    'min_fan_speed' => {
        label   => 'Min',
        tooltip => 'Ce paramètre représente le minimum PWM(Pulse With Modulation) de votre ventilateur pour travailler.',
        sidetext => '%',
        cli     => 'min-fan-speed=i',
        type    => 'i',
        max     => 100,
        default => 35,
    },
    'max_fan_speed' => {
        label   => 'Max',
        tooltip => 'Ce paramètre représente la vitesse maximale de votre ventilateur.',
        sidetext => '%',
        cli     => 'max-fan-speed=i',
        type    => 'i',
        max     => 100,
        default => 100,
    },
    'bridge_fan_speed' => {
        label   => 'Vitesse de ventillateur pour pont',
        tooltip => 'C\'est la vitesse du ventilateur à appliquée au cours de tous les ponts et les surplombs.',
        sidetext => '%',
        cli     => 'bridge-fan-speed=i',
        type    => 'i',
        max     => 100,
        default => 100,
    },
    'fan_below_layer_time' => {
        label   => 'Activer le ventilateur si le temps d\'impression de la couche est inférieure à',
        tooltip => 'Si le temps d\'impression de couche estimé est inférieur à ce nombre de secondes, le ventilateur est activé et sa vitesse est calculée par interpolation des vitesses minimum et maximum.',
        sidetext => 'approximate seconds',
        cli     => 'fan-below-layer-time=i',
        type    => 'i',
        max     => 1000,
        width   => 60,
        default => 60,
    },
    'slowdown_below_layer_time' => {
        label   => 'Ralentissez si le temps d\'impression de la couche est inférieure à',
        tooltip => 'Si le temps d\'impression de la couche est estimée en dessous de ce nombre de secondes, la vitesse d\'impression sera réduite pour prolonger la durée de cette valeur.',
        sidetext => 'approximate seconds',
        cli     => 'slowdown-below-layer-time=i',
        type    => 'i',
        max     => 1000,
        width   => 60,
        default => 30,
    },
    'min_print_speed' => {
        label   => 'Vitesse minimum d\'impression',
        tooltip => 'Slic3r ne sera pas à l\'échelle de vitesse vers le bas en dessous de cette vitesse.',
        sidetext => 'mm/s',
        cli     => 'min-print-speed=f',
        type    => 'i',
        max     => 1000,
        default => 10,
    },
    'disable_fan_first_layers' => {
        label   => 'Arrêter le ventillateur pour les première couches',
        tooltip => 'Vous pouvez définir cette valeur positive pour désactiver le ventillateur pendant les premières couches, de sorte qu\'il ne rende pas l\'adhérence pire.',
        sidetext => 'layers',
        cli     => 'disable-fan-first-layers=i',
        type    => 'i',
        max     => 1000,
        default => 1,
    },
    'fan_always_on' => {
        label   => 'Gardez toujours le ventilateur',
        tooltip => 'Si ce dernier est activé, le ventilateur ne sera jamais désactivée et sera maintenu en marche, au moins à sa vitesse minimale. Utile pour PLA, nocif pour l\'ABS.',
        cli     => 'fan-always-on!',
        type    => 'bool',
        default => 0,
    },
    
    # skirt/brim options
    'skirts' => {
        label   => 'Boucles',
        tooltip => 'Nombre de boucles de cette jupe, en d\'autres termes son épaisseur. Mettre ce paramètre à zéro pour désactiver la jupe.',
        cli     => 'skirts=i',
        type    => 'i',
        default => 1,
    },
    'min_skirt_length' => {
        label   => 'Longueur d\'extrusion minimum',
        tooltip => 'Générer pas moins que le nombre de boucles jupe nécessaire pour consommer la quantité spécifiée de fil sur ​​la couche inférieure. Pour les machines multi-extrusion, ce minimum s\'applique à chaque extrudeuse.',
        sidetext => 'mm',
        cli     => 'min-skirt-length=f',
        type    => 'f',
        default => 0,
        min     => 0,
    },
    'skirt_distance' => {
        label   => 'Distance de l\'objet',
        tooltip => 'Distance entre la jupe et de l\'objet (s). Mettre ce paramètre à zéro pour fixer la jupe à l\'objet (s) et obtenir un bord pour une meilleure adhérence.',
        sidetext => 'mm',
        cli     => 'skirt-distance=f',
        type    => 'f',
        default => 6,
    },
    'skirt_height' => {
        label   => 'Hauteur de la jupe',
        tooltip => 'Hauteur de la jupe exprimé en couches. Réglez-le sur une valeur de hauteur afin d\'utiliser la jupe comme un bouclier contre les courants d\'air.',
        sidetext => 'layers',
        cli     => 'skirt-height=i',
        type    => 'i',
        default => 1,
    },
    'brim_width' => {
        label   => 'Largeur de bord',
        tooltip => 'Largeur horizontale de l\'aile qui sera imprimée autour de chaque objet sur ​​la première couche.',
        sidetext => 'mm',
        cli     => 'brim-width=f',
        type    => 'f',
        default => 0,
    },
    
    # transform options
    'scale' => {
        label   => 'Echelle',
        cli     => 'scale=f',
        type    => 'f',
        default => 1,
    },
    'rotate' => {
        label   => 'Rotation',
        sidetext => '°',
        cli     => 'rotate=i',
        type    => 'i',
        max     => 359,
        default => 0,
    },
    'duplicate' => {
        label   => 'Copies (Arrangement automatique)',
        cli     => 'duplicate=i',
        type    => 'i',
        min     => 1,
        default => 1,
    },
    'bed_size' => {
        label   => 'Taille du lit',
        tooltip => 'Taille de votre lit. Il est utilisé pour ajuster l\'aperçu et les pièces en arrangment automatique.',
        sidetext => 'mm',
        cli     => 'bed-size=s',
        type    => 'point',
        serialize   => $serialize_comma,
        deserialize => sub { [ split /[,x]/, $_[0] ] },
        default => [200,200],
    },
    'duplicate_grid' => {
        label   => 'Copies (grille)',
        cli     => 'duplicate-grid=s',
        type    => 'point',
        serialize   => $serialize_comma,
        deserialize => sub { [ split /[,x]/, $_[0] ] },
        default => [1,1],
    },
    'duplicate_distance' => {
        label   => 'Distance entre les copie',
        tooltip => 'Distance utilisé pour la fonction d\'Arrangement automatique.',
        sidetext => 'mm',
        cli     => 'duplicate-distance=f',
        type    => 'f',
        aliases => [qw(multiply_distance)],
        default => 6,
    },
    
    # sequential printing options
    'complete_objects' => {
        label   => 'Rempliossage d\'objets individuels',
        tooltip => 'Lorsque vous imprimez plusieurs objets ou des copies, cette fonction compléte chaque objet avant de passer au suivant (et à partir de sa couche inférieure). Cette fonction est utile pour éviter le risque de tirages en ruine. Slic3r devrait vous avertir et vous empêcher des collisions d\'extrudeuse, mais méfiez-vous.',
        cli     => 'complete-objects!',
        type    => 'bool',
        default => 0,
    },
    'extruder_clearance_radius' => {
        label   => 'Rayon',
        tooltip => 'Réglez-le rayon de dégagement autour de votre extrudeuse. Si l\'extrudeuse n\'est pas centrée, choisir la plus grande valeur pour la sécurité. Ce paramètre est utilisé pour vérifier les collisions et pour afficher l\'aperçu graphique.',
        sidetext => 'mm',
        cli     => 'extruder-clearance-radius=f',
        type    => 'f',
        default => 20,
    },
    'extruder_clearance_height' => {
        label   => 'Hauteur',
        tooltip => 'Réglez-le sur la distance verticale entre le bout de la buse et (généralement) les X chariot tiges. En d\'autres termes, c\'est la hauteur du cylindre de dégagement autour de votre extrudeuse, qui représente la profondeur maximale de l\'extrudeuse avant de heurter d\'autres objets imprimés.',
        sidetext => 'mm',
        cli     => 'extruder-clearance-height=f',
        type    => 'f',
        default => 20,
    },
};

# generate accessors
if (eval "use Class::XSAccessor; 1") {
    Class::XSAccessor->import(
        getters => { map { $_ => $_ } keys %$Options },
    );
} else {
    no strict 'refs';
    for my $opt_key (keys %$Options) {
        *{$opt_key} = sub { $_[0]{$opt_key} };
    }
}

sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = bless {}, $class;
    $self->apply(%args);
    return $self;
}

sub new_from_defaults {
    my $class = shift;
    
    return $class->new(
        map { $_ => $Options->{$_}{default} }
            grep !$Options->{$_}{shortcut},
            (@_ ? @_ : keys %$Options)
    );
}

sub new_from_cli {
    my $class = shift;
    my %args = @_;
    
    delete $args{$_} for grep !defined $args{$_}, keys %args;
    
    for (qw(start end layer toolchange)) {
        my $opt_key = "${_}_gcode";
        if ($args{$opt_key}) {
            if (-e $args{$opt_key}) {
                Slic3r::open(\my $fh, "<", $args{$opt_key})
                    or die "Erreur d\'ouverture $args{$opt_key}\n";
                binmode $fh, ':utf8';
                $args{$opt_key} = do { local $/; <$fh> };
                close $fh;
            }
        }
    }
    
    $args{$_} = $Options->{$_}{deserialize}->($args{$_})
        for grep exists $args{$_}, qw(print_center bed_size duplicate_grid extruder_offset retract_layer_change wipe);
    
    return $class->new(%args);
}

sub merge {
    my $class = shift;
    my $config = $class->new;
    $config->apply($_) for @_;
    return $config;
}

sub load {
    my $class = shift;
    my ($file) = @_;
    
    my $ini = __PACKAGE__->read_ini($file);
    my $config = __PACKAGE__->new;
    $config->set($_, $ini->{_}{$_}, 1) for keys %{$ini->{_}};
    return $config;
}

sub apply {
    my $self = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_; # accept a single Config object too
    
    $self->set($_, $args{$_}) for keys %args;
}

sub clone {
    my $self = shift;
    my $new = __PACKAGE__->new(%$self);
    $new->{$_} = [@{$new->{$_}}] for grep { ref $new->{$_} eq 'ARRAY' } keys %$new;
    return $new;
}

sub get_value {
    my $self = shift;
    my ($opt_key) = @_;
    
    no strict 'refs';
    my $value = $self->get($opt_key);
    $value = $self->get_value($Options->{$opt_key}{ratio_over}) * $1/100
        if $Options->{$opt_key}{ratio_over} && $value =~ /^(\d+(?:\.\d+)?)%$/;
    return $value;
}

sub get {
    my $self = shift;
    my ($opt_key) = @_;
    
    return $self->{$opt_key};
}

sub set {
    my $self = shift;
    my ($opt_key, $value, $deserialize) = @_;
    
    # handle legacy options
    return if first { $_ eq $opt_key } @Ignore;
    if ($opt_key =~ /^(extrusion_width|bottom_layer_speed|first_layer_height)_ratio$/) {
        $opt_key = $1;
        $opt_key =~ s/^bottom_layer_speed$/first_layer_speed/;
        $value = $value =~ /^\d+(?:\.\d+)?$/ && $value != 0 ? ($value*100) . "%" : 0;
    }
    if ($opt_key eq 'threads' && !$Slic3r::have_threads) {
        $value = 1;
    }
    if ($opt_key eq 'gcode_flavor' && $value eq 'makerbot') {
        $value = 'makerware';
    }
    
    # For historical reasons, the world's full of configs having these very low values;
    # to avoid unexpected behavior we need to ignore them.  Banning these two hard-coded
    # values is a dirty hack and will need to be removed sometime in the future, but it
    # will avoid lots of complaints for now.
    if ($opt_key eq 'perimeter_acceleration' && $value == '25') {
        $value = 0;
    }
    if ($opt_key eq 'infill_acceleration' && $value == '50') {
        $value = 0;
    }
    
    if (!exists $Options->{$opt_key}) {
        my @keys = grep { $Options->{$_}{aliases} && grep $_ eq $opt_key, @{$Options->{$_}{aliases}} } keys %$Options;
        if (!@keys) {
            warn "Unknown option $opt_key\n";
            return;
        }
        $opt_key = $keys[0];
    }
    
    # clone arrayrefs
    $value = [@$value] if ref $value eq 'ARRAY';
    
    # deserialize if requested
    $value = $Options->{$opt_key}{deserialize}->($value)
        if $deserialize && $Options->{$opt_key}{deserialize};
    
    $self->{$opt_key} = $value;
    
    if ($Options->{$opt_key}{shortcut}) {
        $self->set($_, $value, $deserialize) for @{$Options->{$opt_key}{shortcut}};
    }
}

sub set_ifndef {
    my $self = shift;
    my ($opt_key, $value, $deserialize) = @_;
    
    $self->set($opt_key, $value, $deserialize)
        if !defined $self->get($opt_key);
}

sub has {
    my $self = shift;
    my ($opt_key) = @_;
    return exists $self->{$opt_key};
}

sub serialize {
    my $self = shift;
    my ($opt_key) = @_;
    
    my $value = $self->get($opt_key);
    $value = $Options->{$opt_key}{serialize}->($value) if $Options->{$opt_key}{serialize};
    return $value;
}

sub save {
    my $self = shift;
    my ($file) = @_;
    
    my $ini = { _ => {} };
    foreach my $opt_key (sort keys %$self) {
        next if $Options->{$opt_key}{shortcut};
        next if $Options->{$opt_key}{gui_only};
        $ini->{_}{$opt_key} = $self->serialize($opt_key);
    }
    __PACKAGE__->write_ini($file, $ini);
}

sub setenv {
    my $self = shift;
    
    foreach my $opt_key (sort keys %$Options) {
        next if $Options->{$opt_key}{gui_only};
        $ENV{"SLIC3R_" . uc $opt_key} = $self->serialize($opt_key);
    }
}

# this method is idempotent by design
sub validate {
    my $self = shift;
    
    # -j, --threads
    die "Invalid value for --threads\n"
        if $self->threads < 1;
    die "Your perl wasn't built with multithread support\n"
        if $self->threads > 1 && !$Slic3r::have_threads;

    # --layer-height
    die "Invalid value for --layer-height\n"
        if $self->layer_height <= 0;
    die "--layer-height must be a multiple of print resolution\n"
        if $self->layer_height / &Slic3r::SCALING_FACTOR % 1 != 0;
    
    # --first-layer-height
    die "Invalid value for --first-layer-height\n"
        if $self->first_layer_height !~ /^(?:\d*(?:\.\d+)?)%?$/;
    
    # --filament-diameter
    die "Invalid value for --filament-diameter\n"
        if grep $_ < 1, @{$self->filament_diameter};
    
    # --nozzle-diameter
    die "Invalid value for --nozzle-diameter\n"
        if grep $_ < 0, @{$self->nozzle_diameter};
    die "--layer-height can't be greater than --nozzle-diameter\n"
        if grep $self->layer_height > $_, @{$self->nozzle_diameter};
    die "First layer height can't be greater than --nozzle-diameter\n"
        if grep $self->get_value('first_layer_height') > $_, @{$self->nozzle_diameter};
    
    # --perimeters
    die "Invalid value for --perimeters\n"
        if $self->perimeters < 0;
    
    # --solid-layers
    die "Invalid value for --solid-layers\n" if defined $self->solid_layers && $self->solid_layers < 0;
    die "Invalid value for --top-solid-layers\n"    if $self->top_solid_layers      < 0;
    die "Invalid value for --bottom-solid-layers\n" if $self->bottom_solid_layers   < 0;
    
    # --gcode-flavor
    die "Invalid value for --gcode-flavor\n"
        if !first { $_ eq $self->gcode_flavor } @{$Options->{gcode_flavor}{values}};
    
    # --print-center
    die "Invalid value for --print-center\n"
        if !ref $self->print_center 
            && (!$self->print_center || $self->print_center !~ /^\d+,\d+$/);
    
    # --fill-pattern
    die "Invalid value for --fill-pattern\n"
        if !first { $_ eq $self->fill_pattern } @{$Options->{fill_pattern}{values}};
    
    # --solid-fill-pattern
    die "Invalid value for --solid-fill-pattern\n"
        if !first { $_ eq $self->solid_fill_pattern } @{$Options->{solid_fill_pattern}{values}};
    
    # --fill-density
    die "Invalid value for --fill-density\n"
        if $self->fill_density < 0 || $self->fill_density > 1;
    die "The selected fill pattern is not supposed to work at 100% density\n"
        if $self->fill_density == 1
            && !first { $_ eq $self->fill_pattern } @{$Options->{solid_fill_pattern}{values}};
    
    # --infill-every-layers
    die "Invalid value for --infill-every-layers\n"
        if $self->infill_every_layers !~ /^\d+$/ || $self->infill_every_layers < 1;
    
    # --scale
    die "Invalid value for --scale\n"
        if $self->scale <= 0;
    
    # --bed-size
    die "Invalid value for --bed-size\n"
        if !ref $self->bed_size 
            && (!$self->bed_size || $self->bed_size !~ /^\d+,\d+$/);
    
    # --duplicate-grid
    die "Invalid value for --duplicate-grid\n"
        if !ref $self->duplicate_grid 
            && (!$self->duplicate_grid || $self->duplicate_grid !~ /^\d+,\d+$/);
    
    # --duplicate
    die "Invalid value for --duplicate or --duplicate-grid\n"
        if !$self->duplicate || $self->duplicate < 1 || !$self->duplicate_grid
            || (grep !$_, @{$self->duplicate_grid});
    die "Use either --duplicate or --duplicate-grid (using both doesn't make sense)\n"
        if $self->duplicate > 1 && $self->duplicate_grid && (grep $_ && $_ > 1, @{$self->duplicate_grid});
    
    # --skirt-height
    die "Invalid value for --skirt-height\n"
        if $self->skirt_height < 0;
    
    # --bridge-flow-ratio
    die "Invalid value for --bridge-flow-ratio\n"
        if $self->bridge_flow_ratio <= 0;
    
    # extruder clearance
    die "Invalid value for --extruder-clearance-radius\n"
        if $self->extruder_clearance_radius <= 0;
    die "Invalid value for --extruder-clearance-height\n"
        if $self->extruder_clearance_height <= 0;
    
    # --extrusion-multiplier
    die "Invalid value for --extrusion-multiplier\n"
        if defined first { $_ <= 0 } @{$self->extrusion_multiplier};
    
    # --default-acceleration
    die "Valeur Invalide de zéro pour  --default-acceleration en utilisant d'autres paramètres d'accélération\n"
        if ($self->perimeter_acceleration || $self->infill_acceleration || $self->bridge_acceleration || $self->first_layer_acceleration)
            && !$self->default_acceleration;
    
    # general validation, quick and dirty
    foreach my $opt_key (keys %$Options) {
        my $opt = $Options->{$opt_key};
        next unless defined $self->$opt_key;
        next unless defined $opt->{cli} && $opt->{cli} =~ /=(.+)$/;
        my $type = $1;
        my @values = ();
        if ($type =~ s/\@$//) {
            die "Invalid value for $opt_key\n" if ref($self->$opt_key) ne 'ARRAY';
            @values = @{ $self->$opt_key };
        } else {
            @values = ($self->$opt_key);
        }
        foreach my $value (@values) {
            if ($type eq 'i' || $type eq 'f') {
                die "Invalid value for $opt_key\n"
                    if ($type eq 'i' && $value !~ /^-?\d+$/)
                    || ($type eq 'f' && $value !~ /^-?(?:\d+|\d*\.\d+)$/)
                    || (defined $opt->{min} && $value < $opt->{min})
                    || (defined $opt->{max} && $value > $opt->{max});
            } elsif ($type eq 's' && $opt->{type} eq 'select') {
                die "Invalid value for $opt_key\n"
                    unless first { $_ eq $value } @{ $opt->{values} };
            }
        }
    }
}

sub replace_options {
    my $self = shift;
    my ($string, $more_variables) = @_;
    
    $more_variables ||= {};
    $more_variables->{$_} = $ENV{$_} for grep /^SLIC3R_/, keys %ENV;
    {
        my $variables_regex = join '|', keys %$more_variables;
        $string =~ s/\[($variables_regex)\]/$more_variables->{$1}/eg;
    }
    
    my @lt = localtime; $lt[5] += 1900; $lt[4] += 1;
    $string =~ s/\[timestamp\]/sprintf '%04d%02d%02d-%02d%02d%02d', @lt[5,4,3,2,1,0]/egx;
    $string =~ s/\[year\]/$lt[5]/eg;
    $string =~ s/\[month\]/$lt[4]/eg;
    $string =~ s/\[day\]/$lt[3]/eg;
    $string =~ s/\[hour\]/$lt[2]/eg;
    $string =~ s/\[minute\]/$lt[1]/eg;
    $string =~ s/\[second\]/$lt[0]/eg;
    $string =~ s/\[version\]/$Slic3r::VERSION/eg;
    
    # build a regexp to match the available options
    my @options = grep !$Slic3r::Config::Options->{$_}{multiline},
        grep $self->has($_),
        keys %{$Slic3r::Config::Options};
    my $options_regex = join '|', @options;
    
    # use that regexp to search and replace option names with option values
    $string =~ s/\[($options_regex)\]/$self->serialize($1)/eg;
    foreach my $opt_key (grep ref $self->$_ eq 'ARRAY', @options) {
        my $value = $self->$opt_key;
        $string =~ s/\[${opt_key}_${_}\]/$value->[$_]/eg for 0 .. $#$value;
        if ($Options->{$opt_key}{type} eq 'point') {
            $string =~ s/\[${opt_key}_X\]/$value->[0]/eg;
            $string =~ s/\[${opt_key}_Y\]/$value->[1]/eg;
        }
    }
    return $string;
}

# min object distance is max(duplicate_distance, clearance_radius)
sub min_object_distance {
    my $self = shift;
    
    return ($self->complete_objects && $self->extruder_clearance_radius > $self->duplicate_distance)
        ? $self->extruder_clearance_radius
        : $self->duplicate_distance;
}

# CLASS METHODS:

sub write_ini {
    my $class = shift;
    my ($file, $ini) = @_;
    
    Slic3r::open(\my $fh, '>', $file);
    binmode $fh, ':utf8';
    my $localtime = localtime;
    printf $fh "# generated by Slic3r $Slic3r::VERSION on %s\n", "$localtime";
    foreach my $category (sort keys %$ini) {
        printf $fh "\n[%s]\n", $category if $category ne '_';
        foreach my $key (sort keys %{$ini->{$category}}) {
            printf $fh "%s = %s\n", $key, $ini->{$category}{$key};
        }
    }
    close $fh;
}

sub read_ini {
    my $class = shift;
    my ($file) = @_;
    
    local $/ = "\n";
    Slic3r::open(\my $fh, '<', $file);
    binmode $fh, ':utf8';
    
    my $ini = { _ => {} };
    my $category = '_';
    while (<$fh>) {
        s/\R+$//;
        next if /^\s+/;
        next if /^$/;
        next if /^\s*#/;
        if (/^\[(\w+)\]$/) {
            $category = $1;
            next;
        }
        /^(\w+) = (.*)/ or die "Fichier de configuration illisible (données non valides à la ligne $.)\n";
        $ini->{$category}{$1} = $2;
    }
    close $fh;
    
    return $ini;
}

1;
