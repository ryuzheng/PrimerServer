<?php

$urls = explode(' ', $_GET['urls']);

foreach ($urls as $url) {
    unlink("../temp/$url");
}
