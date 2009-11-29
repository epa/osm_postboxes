package Postboxes;
use Modern::Perl;
use List::Util qw(min max);
use lib '.';
use OSM;
use Dracos;

# Given a postcode prefix such as 'E10' and an amount of padding in metres,
# return
#   listref of Dracos data, in OSM-ish format (hash with lat, lon, and tags)
#   listref of OSM data, in same format
# The padding is there to fetch a slightly larger area from OSM than the
# bounding box of the Dracos nodes.
#
sub get_two_data_sets {
    my ($postcode_prefix, $padding) = @_;
    $postcode_prefix =~ /\A[A-Z]+[0-9]+\z/
	or die "bad postcode prefix $postcode_prefix\n";

    # Get Dracos nodes for this prefix.
    my @dracos_data
	= grep { ($_->{postal_code} // '') =~ /\A$postcode_prefix\s/o }
          Dracos::get_data;
    die "no Dracos postboxes found with postcode prefix $postcode_prefix"
	if not @dracos_data;
    warn scalar(@dracos_data), " Dracos postboxes found in $postcode_prefix";

    # Find the bounding box of this postcode area from the Dracos data.
    my @lats = map { $_->{lat} } @dracos_data;
    my @lons = map { $_->{lon} } @dracos_data;
    my @bbox = (min(@lons), min(@lats), max(@lons), max(@lats));

    # Enlarge it a little and fetch the OSM data.
    @bbox = OSM::pad_bbox $padding, @bbox;
    OSM::show_slippy_map_link_for_bbox @bbox;
    my $data = OSM::get_area_bbox @bbox;

    # Parse the OSM data and get postboxes.
    my @nodes = OSM::parse_nodes $data;
    my @osm_postbox_nodes
	= grep { exists $_->{amenity} and $_->{amenity} eq 'post_box' } @nodes;
    warn scalar(@osm_postbox_nodes) . " nearby post boxes found in OSM\n";

    return (\@dracos_data, \@osm_postbox_nodes);
}

1;
