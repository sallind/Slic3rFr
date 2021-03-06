package Slic3r::GUI::Tab;
use strict;
use warnings;
use utf8;

use File::Basename qw(basename);
use List::Util qw(first);
use Wx qw(:bookctrl :dialog :keycode :icon :id :misc :panel :sizer :treectrl :window);
use Wx::Event qw(EVT_BUTTON EVT_CHOICE EVT_KEY_DOWN EVT_TREE_SEL_CHANGED);
use base 'Wx::Panel';

sub new {
    my $class = shift;
    my ($parent, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT | wxTAB_TRAVERSAL);
    $self->{options} = []; # array of option names handled by this tab
    $self->{$_} = $params{$_} for qw(on_value_change on_presets_changed);
    
    # horizontal sizer
    $self->{sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sizer}->SetSizeHints($self);
    $self->SetSizer($self->{sizer});
    
    # left vertical sizer
    my $left_sizer = Wx::BoxSizer->new(wxVERTICAL);
    $self->{sizer}->Add($left_sizer, 0, wxEXPAND | wxLEFT | wxTOP | wxBOTTOM, 3);
    
    my $left_col_width = 150;
    
    # preset chooser
    {
        
        # choice menu
        $self->{presets_choice} = Wx::Choice->new($self, -1, wxDefaultPosition, [$left_col_width, -1], []);
        $self->{presets_choice}->SetFont($Slic3r::GUI::small_font);
        
        # buttons
        $self->{btn_save_preset} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("$Slic3r::var/disk.png", wxBITMAP_TYPE_PNG));
        $self->{btn_delete_preset} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("$Slic3r::var/delete.png", wxBITMAP_TYPE_PNG));
        $self->{btn_save_preset}->SetToolTipString("Enregistrer courrant " . lc($self->title));
        $self->{btn_delete_preset}->SetToolTipString("Supprimer cet enregistrement");
        $self->{btn_delete_preset}->Disable;
        
        ### These cause GTK warnings:
        ###my $box = Wx::StaticBox->new($self, -1, "Presets:", wxDefaultPosition, [$left_col_width, 50]);
        ###my $hsizer = Wx::StaticBoxSizer->new($box, wxHORIZONTAL);
        
        my $hsizer = Wx::BoxSizer->new(wxHORIZONTAL);
        
        $left_sizer->Add($hsizer, 0, wxEXPAND | wxBOTTOM, 5);
        $hsizer->Add($self->{presets_choice}, 1, wxRIGHT | wxALIGN_CENTER_VERTICAL, 3);
        $hsizer->Add($self->{btn_save_preset}, 0, wxALIGN_CENTER_VERTICAL);
        $hsizer->Add($self->{btn_delete_preset}, 0, wxALIGN_CENTER_VERTICAL);
    }
    
    # tree
    $self->{treectrl} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, [$left_col_width, -1], wxTR_NO_BUTTONS | wxTR_HIDE_ROOT | wxTR_SINGLE | wxTR_NO_LINES | wxBORDER_SUNKEN | wxWANTS_CHARS);
    $left_sizer->Add($self->{treectrl}, 1, wxEXPAND);
    $self->{icons} = Wx::ImageList->new(16, 16, 1);
    $self->{treectrl}->AssignImageList($self->{icons});
    $self->{iconcount} = -1;
    $self->{treectrl}->AddRoot("root");
    $self->{pages} = [];
    $self->{treectrl}->SetIndent(0);
    EVT_TREE_SEL_CHANGED($parent, $self->{treectrl}, sub {
        my $page = first { $_->{title} eq $self->{treectrl}->GetItemText($self->{treectrl}->GetSelection) } @{$self->{pages}}
            or return;
        $_->Hide for @{$self->{pages}};
        $page->Show;
        $self->{sizer}->Layout;
        $self->Refresh;
    });
    EVT_KEY_DOWN($self->{treectrl}, sub {
        my ($treectrl, $event) = @_;
        if ($event->GetKeyCode == WXK_TAB) {
            $treectrl->Navigate($event->ShiftDown ? &Wx::wxNavigateBackward : &Wx::wxNavigateForward);
        } else {
            $event->Skip;
        }
    });
    
    EVT_CHOICE($parent, $self->{presets_choice}, sub {
        $self->on_select_preset;
        $self->on_presets_changed;
    });
    
    EVT_BUTTON($self, $self->{btn_save_preset}, sub {
        
        # since buttons (and choices too) don't get focus on Mac, we set focus manually
        # to the treectrl so that the EVT_* events are fired for the input field having
        # focus currently. is there anything better than this?
        $self->{treectrl}->SetFocus;
        
        my $preset = $self->current_preset;
        my $default_name = $preset->{default} ? 'SansTitre' : basename($preset->{name});
        $default_name =~ s/\.ini$//i;
        
        my $dlg = Slic3r::GUI::SavePresetWindow->new($self,
            title   => lc($self->title),
            default => $default_name,
            values  => [ map { my $name = $_->{name}; $name =~ s/\.ini$//i; $name } @{$self->{presets}} ],
        );
        return unless $dlg->ShowModal == wxID_OK;
        
        my $file = sprintf "$Slic3r::GUI::datadir/%s/%s.ini", $self->name, $dlg->get_name;
        $self->config->save($file);
        $self->set_dirty(0);
        $self->load_presets;
        $self->{presets_choice}->SetSelection(first { basename($self->{presets}[$_]{file}) eq $dlg->get_name . ".ini" } 1 .. $#{$self->{presets}});
        $self->on_select_preset;
        $self->on_presets_changed;
    });
    
    EVT_BUTTON($self, $self->{btn_delete_preset}, sub {
        my $i = $self->{presets_choice}->GetSelection;
        return if $i == 0;  # this shouldn't happen but let's trap it anyway
        my $res = Wx::MessageDialog->new($self, "Etes vous sur de vouloir supprimer cette enregistrement", 'Supprimer l\'enregistrement', wxYES_NO | wxNO_DEFAULT | wxICON_QUESTION)->ShowModal;
        return unless $res == wxID_YES;
        if (-e $self->{presets}[$i]{file}) {
            unlink $self->{presets}[$i]{file};
        }
        splice @{$self->{presets}}, $i, 1;
        $self->set_dirty(0);
        $self->{presets_choice}->Delete($i);
        $self->{presets_choice}->SetSelection(0);
        $self->on_select_preset;
        $self->on_presets_changed;
    });
    
    $self->{config} = Slic3r::Config->new;
    $self->build;
    if ($self->hidden_options) {
        $self->{config}->apply(Slic3r::Config->new_from_defaults($self->hidden_options));
        push @{$self->{options}}, $self->hidden_options;
    }
    $self->load_presets;
    
    return $self;
}

sub current_preset {
    my $self = shift;
    return $self->{presets}[ $self->{presets_choice}->GetSelection ];
}

sub get_preset {
    my $self = shift;
    return $self->{presets}[ $_[0] ];
}

# propagate event to the parent
sub on_value_change {
    my $self = shift;
    $self->{on_value_change}->(@_) if $self->{on_value_change};
}

sub on_presets_changed {
    my $self = shift;
    $self->{on_presets_changed}->([$self->{presets_choice}->GetStrings], $self->{presets_choice}->GetSelection)
        if $self->{on_presets_changed};
}

sub on_preset_loaded {}
sub hidden_options {}
sub config { $_[0]->{config}->clone }

sub select_default_preset {
    my $self = shift;
    $self->{presets_choice}->SetSelection(0);
}

sub select_preset {
    my $self = shift;
    $self->{presets_choice}->SetSelection($_[0]);
    $self->on_select_preset;
}

sub on_select_preset {
    my $self = shift;
    
    if (defined $self->{dirty}) {
        my $name = $self->{dirty} == 0 ? 'Default preset' : "Preset \"$self->{presets}[$self->{dirty}]{name}\"";
        my $confirm = Wx::MessageDialog->new($self, "$name n\'est pas enregistré. Annuler les changements ou continuer?",
                                             'Annuler les changements', wxYES_NO | wxNO_DEFAULT | wxICON_QUESTION);
        if ($confirm->ShowModal == wxID_NO) {
            $self->{presets_choice}->SetSelection($self->{dirty});
            return;
        }
        $self->set_dirty(0);
    }
    
    my $preset = $self->current_preset;
    my $preset_config = $self->get_preset_config($preset);
    eval {
        local $SIG{__WARN__} = Slic3r::GUI::warning_catcher($self);
        foreach my $opt_key (@{$self->{options}}) {
            $self->{config}->set($opt_key, $preset_config->get($opt_key))
                if $preset_config->has($opt_key);
        }
        ($preset->{default} || $preset->{external})
            ? $self->{btn_delete_preset}->Disable
            : $self->{btn_delete_preset}->Enable;
        
        $self->on_preset_loaded;
        $self->reload_values;
        $self->set_dirty(0);
        $Slic3r::GUI::Settings->{presets}{$self->name} = $preset->{file} ? basename($preset->{file}) : '';
    };
    if ($@) {
        $@ = "Il n'est pas possible de séléctionner le fichier de configuration: $@";
        Slic3r::GUI::catch_error($self);
        $self->select_default_preset;
    }
    
    Slic3r::GUI->save_settings;
}

sub get_preset_config {
    my $self = shift;
    my ($preset) = @_;
    
    if ($preset->{default}) {
        return Slic3r::Config->new_from_defaults(@{$self->{options}});
    } else {
        if (!-e $preset->{file}) {
            Slic3r::GUI::show_error($self, "Le préréglage sélectionné n\'existe plus ($preset->{file}).");
            return;
        }
        
        # apply preset values on top of defaults
        my $external_config = Slic3r::Config->load($preset->{file});
        my $config = Slic3r::Config->new;
        $config->set($_, $external_config->get($_))
            for grep $external_config->has($_), @{$self->{options}};
        
        return $config;
    }
}

sub add_options_page {
    my $self = shift;
    my ($title, $icon, %params) = @_;
    
    if ($icon) {
        my $bitmap = Wx::Bitmap->new("$Slic3r::var/$icon", wxBITMAP_TYPE_PNG);
        $self->{icons}->Add($bitmap);
        $self->{iconcount}++;
    }
    
    {
        # get all config options being added to the current page; remove indexes; associate defaults
        my @options = map { $_ =~ s/#.+//; $_ } grep !ref($_), map @{$_->{options}}, @{$params{optgroups}};
        my %defaults_to_set = map { $_ => 1 } @options;
        
        # apply default values for the options we don't have already
        delete $defaults_to_set{$_} for @{$self->{options}};
        $self->{config}->apply(Slic3r::Config->new_from_defaults(keys %defaults_to_set)) if %defaults_to_set;
        
        # append such options to our list
        push @{$self->{options}}, @options;
    }
    
    my $page = Slic3r::GUI::Tab::Page->new($self, $title, $self->{iconcount}, %params, on_change => sub {
        $self->on_value_change(@_);
        $self->set_dirty(1);
        $self->on_presets_changed;
    });
    $page->Hide;
    $self->{sizer}->Add($page, 1, wxEXPAND | wxLEFT, 5);
    push @{$self->{pages}}, $page;
    $self->update_tree;
    return $page;
}

sub set_value {
    my $self = shift;
    my ($opt_key, $value) = @_;
    
    my $changed = 0;
    foreach my $page (@{$self->{pages}}) {
        $changed = 1 if $page->set_value($opt_key, $value);
    }
    return $changed;
}

sub reload_values {
    my $self = shift;
    
    $self->set_value($_, $self->{config}->get($_)) for keys %{$self->{config}};
}

sub update_tree {
    my $self = shift;
    my ($select) = @_;
    
    $select //= 0; #/
    
    my $rootItem = $self->{treectrl}->GetRootItem;
    $self->{treectrl}->DeleteChildren($rootItem);
    foreach my $page (@{$self->{pages}}) {
        my $itemId = $self->{treectrl}->AppendItem($rootItem, $page->{title}, $page->{iconID});
        $self->{treectrl}->SelectItem($itemId) if $self->{treectrl}->GetChildrenCount($rootItem) == $select + 1;
    }
}

sub set_dirty {
    my $self = shift;
    my ($dirty) = @_;
    
    my $selection = $self->{presets_choice}->GetSelection;
    my $i = $self->{dirty} // $selection; #/
    my $text = $self->{presets_choice}->GetString($i);
    
    if ($dirty) {
        $self->{dirty} = $i;
        if ($text !~ / \(modified\)$/) {
            $self->{presets_choice}->SetString($i, "$text (modified)");
            $self->{presets_choice}->SetSelection($selection);  # http://trac.wxwidgets.org/ticket/13769
        }
    } else {
        $self->{dirty} = undef;
        $text =~ s/ \(modified\)$//;
        $self->{presets_choice}->SetString($i, $text);
        $self->{presets_choice}->SetSelection($selection);  # http://trac.wxwidgets.org/ticket/13769
    }
    $self->on_presets_changed;
}

sub is_dirty {
    my $self = shift;
    return (defined $self->{dirty});
}

sub load_presets {
    my $self = shift;
    
    $self->{presets} = [{
        default => 1,
        name    => '- default -',
    }];
    
    opendir my $dh, "$Slic3r::GUI::datadir/" . $self->name or die "Impossible de lire le répertoire $Slic3r::GUI::datadir/" . $self->name . " (errno: $!)\n";
    foreach my $file (sort grep /\.ini$/i, readdir $dh) {
        my $name = basename($file);
        $name =~ s/\.ini$//;
        push @{$self->{presets}}, {
            file => "$Slic3r::GUI::datadir/" . $self->name . "/$file",
            name => $name,
        };
    }
    closedir $dh;
    
    $self->{presets_choice}->Clear;
    $self->{presets_choice}->Append($_->{name}) for @{$self->{presets}};
    {
        # load last used preset
        my $i = first { basename($self->{presets}[$_]{file}) eq ($Slic3r::GUI::Settings->{presets}{$self->name} || '') } 1 .. $#{$self->{presets}};
        $self->{presets_choice}->SetSelection($i || 0);
        $self->on_select_preset;
    }
    $self->on_presets_changed;
}

sub load_config_file {
    my $self = shift;
    my ($file) = @_;
    
    # look for the loaded config among the existing menu items
    my $i = first { $self->{presets}[$_]{file} eq $file && $self->{presets}[$_]{external} } 1..$#{$self->{presets}};
    if (!$i) {
        my $preset_name = basename($file);  # keep the .ini suffix
        push @{$self->{presets}}, {
            file        => $file,
            name        => $preset_name,
            external    => 1,
        };
        $self->{presets_choice}->Append($preset_name);
        $i = $#{$self->{presets}};
    }
    $self->{presets_choice}->SetSelection($i);
    $self->on_select_preset;
    $self->on_presets_changed;
}

package Slic3r::GUI::Tab::Print;
use base 'Slic3r::GUI::Tab';

sub name { 'print' }
sub title { 'Paramètre d\'impression' }

sub build {
    my $self = shift;
    
    $self->add_options_page('Couches et périmètres', 'layers.png', optgroups => [
        {
            title => 'Hauteur de couche',
            options => [qw(layer_height first_layer_height)],
        },
        {
            title => 'Coquille verticale',
            options => [qw(perimeters spiral_vase)],
        },
        {
            title => 'Coquille Horizontale',
            options => [qw(top_solid_layers bottom_solid_layers)],
            lines => [
                {
                    label   => 'Couche solide',
                    options => [qw(top_solid_layers bottom_solid_layers)],
                },
            ],
        },
        {
            title => 'Qualité (tranchage lent)',
            options => [qw(extra_perimeters avoid_crossing_perimeters start_perimeters_at_concave_points start_perimeters_at_non_overhang thin_walls overhangs)],
            lines => [
                Slic3r::GUI::OptionsGroup->single_option_line('extra_perimeters'),
                Slic3r::GUI::OptionsGroup->single_option_line('avoid_crossing_perimeters'),
                {
                    label   => 'Debut du périmètres à',
                    options => [qw(start_perimeters_at_concave_points start_perimeters_at_non_overhang)],
                },
                Slic3r::GUI::OptionsGroup->single_option_line('thin_walls'),
                Slic3r::GUI::OptionsGroup->single_option_line('overhangs'),
            ],
        },
        {
            title => 'Avancé',
            options => [qw(randomize_start external_perimeters_first)],
        },
    ]);
    
    $self->add_options_page('Remplissage', 'shading.png', optgroups => [
        {
            title => 'Remplissage',
            options => [qw(fill_density fill_pattern solid_fill_pattern)],
        },
        {
            title => 'Diminue le temps d\'impression',
            options => [qw(infill_every_layers infill_only_where_needed)],
        },
        {
            title => 'Avancé',
            options => [qw(solid_infill_every_layers fill_angle
                solid_infill_below_area only_retract_when_crossing_perimeters infill_first)],
        },
    ]);
    
    $self->add_options_page('Vitesse', 'time.png', optgroups => [
        {
            title => 'Vitesse de déplacement d\'impression',
            options => [qw(perimeter_speed small_perimeter_speed external_perimeter_speed infill_speed solid_infill_speed top_solid_infill_speed support_material_speed bridge_speed gap_fill_speed)],
        },
        {
            title => 'Vitesse de déplacement sans impression',
            options => [qw(travel_speed)],
        },
        {
            title => 'Modificateurs',
            options => [qw(first_layer_speed)],
        },
        {
            title => 'Commande d\'accélération (avancé)',
            options => [qw(perimeter_acceleration infill_acceleration bridge_acceleration first_layer_acceleration default_acceleration)],
        },
    ]);
    
    $self->add_options_page('Jupe et le bord', 'box.png', optgroups => [
        {
            title => 'Jupe',
            options => [qw(skirts skirt_distance skirt_height min_skirt_length)],
        },
        {
            title => 'Bord',
            options => [qw(brim_width)],
        },
    ]);
    
    $self->add_options_page('Matériaux d\'appui', 'building.png', optgroups => [
        {
            title => 'Matériaux d\'appui',
            options => [qw(support_material support_material_threshold support_material_enforce_layers)],
        },
        {
            title => 'Radier',
            options => [qw(raft_layers)],
        },
        {
            title => 'Options de matériaux d\'appui',
            options => [qw(support_material_pattern support_material_spacing support_material_angle
                support_material_interface_layers support_material_interface_spacing)],
        },
    ]);
    
    $self->add_options_page('Notes', 'note.png', optgroups => [
        {
            title => 'Notes',
            no_labels => 1,
            options => [qw(notes)],
        },
    ]);
    
    $self->add_options_page('Option de sortie', 'page_white_go.png', optgroups => [
        {
            title => 'Impression séquentielle',
            options => [qw(complete_objects extruder_clearance_radius extruder_clearance_height)],
            lines => [
                Slic3r::GUI::OptionsGroup->single_option_line('complete_objects'),
                {
                    label   => 'Dégagement Extrudeur (mm)',
                    options => [qw(extruder_clearance_radius extruder_clearance_height)],
                },
            ],
        },
        {
            title => 'Fichier de sortie',
            options => [qw(gcode_comments output_filename_format)],
        },
        {
            title => 'Scripts de post-traitement',
            no_labels => 1,
            options => [qw(post_process)],
        },
    ]);
    
    $self->add_options_page('Extrudeur multiples', 'funnel.png', optgroups => [
        {
            title => 'Extrudeurs',
            options => [qw(perimeter_extruder infill_extruder support_material_extruder support_material_interface_extruder)],
        },
    ]);
    
    $self->add_options_page('Avancé', 'wrench.png', optgroups => [
        {
            title => 'Largeur d\'extrusion',
            label_width => 180,
            options => [qw(extrusion_width first_layer_extrusion_width perimeter_extrusion_width infill_extrusion_width solid_infill_extrusion_width top_infill_extrusion_width support_material_extrusion_width)],
        },
        {
            title => 'Circulation',
            options => [qw(bridge_flow_ratio)],
        },
        {
            title => 'Autre',
            options => [($Slic3r::have_threads ? qw(threads) : ()), qw(resolution)],
        },
    ]);
}

sub hidden_options { !$Slic3r::have_threads ? qw(threads) : () }

package Slic3r::GUI::Tab::Filament;
use base 'Slic3r::GUI::Tab';

sub name { 'Filament' }
sub title { 'Paramètre de fil' }

sub build {
    my $self = shift;
    
    $self->add_options_page('Tête d\'impression', 'spool.png', optgroups => [
        {
            title => 'Tête d\'impression',
            options => ['filament_diameter#0', 'extrusion_multiplier#0'],
        },
        {
            title => 'Température (°C)',
            options => ['temperature#0', 'first_layer_temperature#0', qw(bed_temperature first_layer_bed_temperature)],
            lines => [
                {
                    label   => 'Extrudeur',
                    options => ['first_layer_temperature#0', 'temperature#0'],
                },
                {
                    label   => 'Lit d\'impression',
                    options => [qw(first_layer_bed_temperature bed_temperature)],
                },
            ],
        },
    ]);
    
    $self->add_options_page('Refroidissement', 'hourglass.png', optgroups => [
        {
            title => 'Marche',
            options => [qw(fan_always_on cooling)],
            lines => [
                Slic3r::GUI::OptionsGroup->single_option_line('fan_always_on'),
                Slic3r::GUI::OptionsGroup->single_option_line('cooling'),
                {
                    label => '',
                    widget => ($self->{description_line} = Slic3r::GUI::OptionsGroup::StaticTextLine->new),
                },
            ],
        },
        {
            title => 'Paramètres du ventillateur',
            options => [qw(min_fan_speed max_fan_speed bridge_fan_speed disable_fan_first_layers)],
            lines => [
                {
                    label   => 'Vitesse du ventillateur',
                    options => [qw(min_fan_speed max_fan_speed)],
                },
                Slic3r::GUI::OptionsGroup->single_option_line('bridge_fan_speed'),
                Slic3r::GUI::OptionsGroup->single_option_line('disable_fan_first_layers'),
            ],
        },
        {
            title => 'Seuils de refroidissement',
            label_width => 250,
            options => [qw(fan_below_layer_time slowdown_below_layer_time min_print_speed)],
        },
    ]);
}

sub _update_description {
    my $self = shift;
    
    my $config = $self->config;
    
    my $msg = "";
    my $fan_other_layers = $config->fan_always_on
        ? sprintf "sera toujours en marche à %d%%%s.", $config->min_fan_speed,
                ($config->disable_fan_first_layers > 1
                    ? " sauf pour la première " . $config->disable_fan_first_layers . " couches"
                    : $config->disable_fan_first_layers == 1
                        ? " sauf pour la première couche"
                        : "")
        : "sera éteint.";
    
    if ($config->cooling) {
        $msg = sprintf "Si le temps de la couche estimé est inférieur à ~%ds, le ventilateur fonctionnera à 100%% et la vitesse d\'impression sera réduite de sorte que pas moins de %ds sont dépensés sur ce calque (cependant, la vitesse ne sera jamais réduite en dessous de %dmm/s).",
            $config->slowdown_below_layer_time, $config->slowdown_below_layer_time, $config->min_print_speed;
        if ($config->fan_below_layer_time > $config->slowdown_below_layer_time) {
            $msg .= sprintf "\nSi le temps de la couche estimée est supérieure, mais encore en dessous ~%ds, le ventilateur tournera à une vitesse décroissante proportionnellement entre %d%% et %d%%.",
                $config->fan_below_layer_time, $config->max_fan_speed, $config->min_fan_speed;
        }
        $msg .= "\nPendant les autres couches, ventiller $fan_other_layers"
    } else {
        $msg = "Ventillateur $fan_other_layers";
    }
    $self->{description_line}->SetText($msg);
}

sub on_value_change {
    my $self = shift;
    my ($opt_key) = @_;
    $self->SUPER::on_value_change(@_);
    
    $self->_update_description;
}

package Slic3r::GUI::Tab::Printer;
use base 'Slic3r::GUI::Tab';

sub name { 'printer' }
sub title { 'Paramètre d\'imprimante' }

sub build {
    my $self = shift;
    
    $self->{extruders_count} = 1;
    
    $self->add_options_page('Général', 'printer_empty.png', optgroups => [
        {
            title => 'Taille et coordonées',
            options => [qw(bed_size print_center z_offset)],
        },
        {
            title => 'Firmware',
            options => [qw(gcode_flavor use_relative_e_distances)],
        },
        {
            title => 'Fonctionnalités',
            options => [
                {
                    opt_key => 'extruders_count',
                    label   => 'Extrudeurs',
                    tooltip => 'Nomdre d\'extrudeurs sur l\'imprimante.',
                    type    => 'i',
                    min     => 1,
                    default => 1,
                    on_change => sub { $self->{extruders_count} = $_[0] },
                },
            ],
        },
        {
            title => 'Avancé',
            options => [qw(vibration_limit)],
        },
    ]);
    
    $self->add_options_page('Amélioration G-code', 'cog.png', optgroups => [
        {
            title => 'G-code du debut',
            no_labels => 1,
            options => [qw(start_gcode)],
        },
        {
            title => 'G-code de fin',
            no_labels => 1,
            options => [qw(end_gcode)],
        },
        {
            title => 'G-code de changement de couche',
            no_labels => 1,
            options => [qw(layer_gcode)],
        },
        {
            title => 'G-code de changement d\'outil',
            no_labels => 1,
            options => [qw(toolchange_gcode)],
        },
    ]);
    
    $self->{extruder_pages} = [];
    $self->_build_extruder_pages;
}

sub _extruder_options { qw(nozzle_diameter extruder_offset retract_length retract_lift retract_speed retract_restart_extra retract_before_travel wipe
    retract_layer_change retract_length_toolchange retract_restart_extra_toolchange) }

sub config {
    my $self = shift;
    
    my $config = $self->SUPER::config(@_);
    
    # remove all unused values
    foreach my $opt_key ($self->_extruder_options) {
        splice @{ $config->{$opt_key} }, $self->{extruders_count};
    }
    
    return $config;
}

sub _build_extruder_pages {
    my $self = shift;
    
    foreach my $extruder_idx (0 .. $self->{extruders_count}-1) {
        # build page if it doesn't exist
        $self->{extruder_pages}[$extruder_idx] ||= $self->add_options_page("Extruder " . ($extruder_idx + 1), 'funnel.png', optgroups => [
            {
                title => 'Taille',
                options => ['nozzle_diameter#' . $extruder_idx],
            },
            {
                title => 'Position (pour les imprimantes à extrudeur multiple)',
                options => ['extruder_offset#' . $extruder_idx],
            },
            {
                title => 'Rétraction',
                options => [
                    map "${_}#${extruder_idx}",
                        qw(retract_length retract_lift retract_speed retract_restart_extra retract_before_travel retract_layer_change wipe)
                ],
            },
            {
                title => 'Rétractation lorsque l\'outil est désactivé (paramètres avancés pour les configurations multi-extrusion)',
                options => [
                    map "${_}#${extruder_idx}",
                        qw(retract_length_toolchange retract_restart_extra_toolchange)
                ],
            },
        ]);
        $self->{extruder_pages}[$extruder_idx]{disabled} = 0;
    }
    
    # rebuild page list
    @{$self->{pages}} = (
        (grep $_->{title} !~ /^Extruder \d+/, @{$self->{pages}}),
        @{$self->{extruder_pages}}[ 0 .. $self->{extruders_count}-1 ],
    );
}

sub on_value_change {
    my $self = shift;
    my ($opt_key) = @_;
    $self->SUPER::on_value_change(@_);
    
    if ($opt_key eq 'extruders_count') {
        # remove unused pages from list
        my @unused_pages = @{ $self->{extruder_pages} }[$self->{extruders_count} .. $#{$self->{extruder_pages}}];
        for my $page (@unused_pages) {
            @{$self->{pages}} = grep $_ ne $page, @{$self->{pages}};
            $page->{disabled} = 1;
        }
        
        # add extra pages
        $self->_build_extruder_pages;
        
        # update page list and select first page (General)
        $self->update_tree(0);
    }
}

# this gets executed after preset is loaded and before GUI fields are updated
sub on_preset_loaded {
    my $self = shift;
    
    # update the extruders count field
    {
        # update the GUI field according to the number of nozzle diameters supplied
        $self->set_value('extruders_count', scalar @{ $self->{config}->nozzle_diameter });
        
        # update extruder page list
        $self->on_value_change('extruders_count');
    }
}

sub load_config_file {
    my $self = shift;
    $self->SUPER::load_config_file(@_);  
  
    Slic3r::GUI::warning_catcher($self)->(
        "Votre configuration a été importé. Cependant, Slic3r n'est actuellement en mesure d\'importer des paramètres "
        . "pour le premier fil défini. Nous vous recommandons de ne pas utiliser les fichiers de configuration exportés "
        . "pour les configurations multi-extrudeurs et de s'appuyer sur le système intégré de gestion des paramètres.")
        if @{ $self->{config}->nozzle_diameter } > 1;
}

package Slic3r::GUI::Tab::Page;
use Wx qw(:misc :panel :sizer);
use base 'Wx::ScrolledWindow';

sub new {
    my $class = shift;
    my ($parent, $title, $iconID, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL);
    $self->{optgroups}  = [];
    $self->{title}      = $title;
    $self->{iconID}     = $iconID;
    
    $self->SetScrollbars(1, 1, 1, 1);
    
    $self->{vsizer} = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($self->{vsizer});
    
    if ($params{optgroups}) {
        $self->append_optgroup(
            %$_,
            config      => $parent->{config},
            on_change   => $params{on_change},
        ) for @{$params{optgroups}};
    }
    
    return $self;
}

sub append_optgroup {
    my $self = shift;
    my %params = @_;
    
    my $class = $params{class} || 'Slic3r::GUI::ConfigOptionsGroup';
    my $optgroup = $class->new(
        parent      => $self,
        config      => $self->GetParent->{config},
        label_width => 200,
        %params,
    );
    $self->{vsizer}->Add($optgroup->sizer, 0, wxEXPAND | wxALL, 5);
    push @{$self->{optgroups}}, $optgroup;
}

sub set_value {
    my $self = shift;
    my ($opt_key, $value) = @_;
    
    my $changed = 0;
    foreach my $optgroup (@{$self->{optgroups}}) {
        $changed = 1 if $optgroup->set_value($opt_key, $value);
    }
    return $changed;
}

package Slic3r::GUI::SavePresetWindow;
use Wx qw(:combobox :dialog :id :misc :sizer);
use Wx::Event qw(EVT_BUTTON EVT_TEXT_ENTER);
use base 'Wx::Dialog';

sub new {
    my $class = shift;
    my ($parent, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, "Enregistrement des préréglage", wxDefaultPosition, wxDefaultSize);
    
    my $text = Wx::StaticText->new($self, -1, "Enregistrement " . lc($params{title}) . " sous:", wxDefaultPosition, wxDefaultSize);
    $self->{combo} = Wx::ComboBox->new($self, -1, $params{default}, wxDefaultPosition, wxDefaultSize, $params{values},
                                       wxTE_PROCESS_ENTER);
    my $buttons = $self->CreateStdDialogButtonSizer(wxOK | wxCANCEL);
    
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    $sizer->Add($text, 0, wxEXPAND | wxTOP | wxLEFT | wxRIGHT, 10);
    $sizer->Add($self->{combo}, 0, wxEXPAND | wxLEFT | wxRIGHT, 10);
    $sizer->Add($buttons, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    
    EVT_BUTTON($self, wxID_OK, \&accept);
    EVT_TEXT_ENTER($self, $self->{combo}, \&accept);
    
    $self->SetSizer($sizer);
    $sizer->SetSizeHints($self);
    
    return $self;
}

sub accept {
    my ($self, $event) = @_;

    if (($self->{chosen_name} = $self->{combo}->GetValue)) {
        if ($self->{chosen_name} =~ /^[^<>:\/\\|?*\"]+$/i) {
            $self->EndModal(wxID_OK);
        } else {
            Slic3r::GUI::show_error($self, "Le nom fourni n'est pas valide, les caractères suivants ne sont pas autorisés: <>:/\|?*\"");
        }
    }
}

sub get_name {
    my $self = shift;
    return $self->{chosen_name};
}

1;
