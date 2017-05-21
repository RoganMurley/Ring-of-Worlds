'use strict';

var gulp = require('gulp');
var elm  = require('gulp-elm');
var plumber = require('gulp-plumber');
var sass = require('gulp-sass');
var uglify = require('gulp-uglify');
var minify = require('gulp-minify-css');


// ELM

gulp.task('init', elm.init);

gulp.task('multi', ['init'], function(){
  return gulp.src('elm/Main.elm')
    .pipe(plumber())
    .pipe(elm.make({filetype: 'js', warn: true}))
    .pipe(uglify())
    .pipe(gulp.dest('static/'));
});


// SASS

gulp.task('sass', function () {
  return gulp.src('./sass/**/*.scss')
    .pipe(plumber())
    .pipe(sass().on('error', sass.logError))
    .pipe(minify())
    .pipe(gulp.dest('./static'));
});


// DEFAULT

gulp.task('default', ['multi', 'sass']);

gulp.task('watch', function(){
  gulp.watch('elm/**/*.elm', ['multi']);
  gulp.watch('./sass/**/*.scss', ['sass']);
});
