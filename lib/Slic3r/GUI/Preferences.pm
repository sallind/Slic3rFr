package Slic3r::GUI::Preferences;
use Wx qw(:dialog :id :misc :sizer :systemsettings);
use Wx::Event qw(EVT_BUTTON EVT_TEXT_ENTER);
use base 'Wx::Dialog';

sub new {
    my $class = shift;
    my ($parent, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, "Preferences", wxDefaultPosition, [500,200]);
    $self->{values};
    
    my $optgroup = Slic3r::GUI::OptionsGroup->new(
        parent  => $self,
        title   => 'General',
        options => [
            {
                opt_key     => 'mode',
                type        => 'select',
                #label       => 'Mode',
                #tooltip     => 'Choose between a simpler, basic mode and an expert mode with more options and more complicated interface.',
                label       => 'Mode',
                tooltip     => 'Choisissez entre un mode de base simple et un mode expert avec plus d\'options et une interface plus compliqué.',
                labels      => ['Simple','Expert'],
                values      => ['simple','expert'],
                default     => $Slic3r::GUI::Settings->{_}{mode},
            },
            {
                opt_key     => 'version_check',
                type        => 'bool',
                #label       => 'Check for updates',
                #tooltip     => 'If this is enabled, Slic3r will check for updates daily and display a reminder if a newer version is available.',
                label       => 'Controler les mise à jour',
                tooltip     => 'Si cette option est activée, Slic3r va vérifier les mises à jour quotidiennement et affiche un rappel si une nouvelle version est disponible.',
                default     => $Slic3r::GUI::Settings->{_}{version_check} // 1,
                readonly    => !Slic3r::GUI->have_version_check,
            },
            {
                opt_key     => 'remember_output_path',
                type        => 'bool',
                #label       => 'Remember output directory',
                #tooltip     => 'If this is enabled, Slic3r will prompt the last output directory instead of the one containing the input files.',
                label       => 'Mémorisé le répertoire de sortie',
                tooltip     => 'Si cette option est activée, Slic3r vous demandera le dernier répertoire de sortie au lieu de celui contenant les fichiers d\'entrée.',
                default     => $Slic3r::GUI::Settings->{_}{remember_output_path},
            },
        ],
        on_change => sub { $self->{values}{$_[0]} = $_[1] },
        label_width => 100,
    );
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    $sizer->Add($optgroup->sizer, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    
    my $buttons = $self->CreateStdDialogButtonSizer(wxOK | wxCANCEL);
    EVT_BUTTON($self, wxID_OK, sub { $self->_accept });
    $sizer->Add($buttons, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    
    $self->SetSizer($sizer);
    $sizer->SetSizeHints($self);
    
    return $self;
}

sub _accept {
    my $self = shift;
    $self->EndModal(wxID_OK);
    
    if ($self->{values}{mode}) {
        #Slic3r::GUI::warning_catcher($self)->("You need to restart Slic3r to make the changes effective.");
        Slic3r::GUI::warning_catcher($self)->("Vous devez redémarrer Slic3r pour appliquer les changements.");
    }
    
    $Slic3r::GUI::Settings->{_}{$_} = $self->{values}{$_} for keys %{$self->{values}};
    Slic3r::GUI->save_settings;
}

1;
