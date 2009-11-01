package OSM;
use Modern::Perl;
use Carp qw(croak);
use Math::Trig;
use LWP::Simple;
my $BASE_URI = 'http://api.openstreetmap.org/api/0.6/';

sub get_area_bbox {
    my ($left, $bottom, $right, $top) = @_;
    croak 'bad bbox: left > right' if $left > $right;
    croak 'bad bbox: bottom > top' if $bottom >= $top;
    my $uri = $BASE_URI . "map?bbox=$left,$bottom,$right,$top";
    my $got = get($uri) //  die "could not get $uri";
    return $got;
}

# Utility functions to convert width and height to degrees of
# longitude and latitude respectively.  Pass the the lat,lon of the
# position you're interested in.
#
sub width_to_lon_degrees {
    my ($lat, $lon, $width) = @_;
    my $cosine = cos(deg2rad($lat));
    my $one_degree_lon_at_equator = 111_000;
    my $one_degree_lon = $one_degree_lon_at_equator * $cosine;
    return $width / $one_degree_lon;
}
sub height_to_lat_degrees {
    my ($lat, $lon, $width) = @_;
    my $one_degree_lat = 111_000;
    return $width / $one_degree_lat;
}

sub get_area_centre {
    my ($centre_lat, $centre_lon, $width, $height) = @_;
    my $cosine = cos(deg2rad($centre_lat));
    my $lat_degrees_high
	= height_to_lat_degrees $centre_lat, $centre_lon, $height;
    my $lon_degrees_wide
	= width_to_lon_degrees $centre_lat, $centre_lon, $width;
    return get_area_bbox
	$centre_lon - ($lon_degrees_wide / 2),
	$centre_lat - ($lat_degrees_high / 2),
	$centre_lon + ($lon_degrees_wide / 2),
	$centre_lat + ($lat_degrees_high / 2);
}

sub get_area_zoom {
    my ($centre_lat, $centre_lon, $zoom, $screen_width, $screen_height) = @_;
    $screen_width //= 1000;
    $screen_height //= 1000;

    my %metres_per_pixel_at_equator = (
	18 => 0.597164,
	17 => 1.194329,
	16 => 2.388657,
	15 => 4.777314,
	14 => 9.554629,
	13 => 19.109257,
	12 => 38.218514,
	11 => 76.437028,
	10 => 152.874057,
	9 => 305.748113,
	8 => 611.496226,
	7 => 1222.992453,
	6 => 2445.984905,
	5 => 4891.969810,
	4 => 9783.939621,
	3 => 19567.879241,
	2 => 39135.758482,
    );
    die "bad zoom $zoom" if not exists $metres_per_pixel_at_equator{$zoom};
    my $cosine = cos(deg2rad($centre_lat));
    my $metres_per_pixel
	= $metres_per_pixel_at_equator{$zoom} / $cosine;
    my $metres_wide = $screen_width * $metres_per_pixel;
    my $metres_high = $screen_height * $metres_per_pixel;
    return get_area_centre $centre_lat, $centre_lon, $metres_wide, $metres_high;
}

1;
