.emacs.d.yas.auto
=================
### power for rails and ruby to emacs.

```bash
$ cd ~/
$ cp .emacs .emacs.bak
$ cp .emacs.d .emacs.d.bak
$ git clone https://github.com/xlgwr/.emacs.d.yas.auto.git .emacs.d
$ cd .emacs.d
$ cp .emacs ~/
$ emacs
```
### rinari key for Rails to emacs.

```text
C-c ; f ;	rinari-find-by-context
C-c ; f C	rinari-find-cells
C-c ; f F	rinari-find-features
C-c ; f M	rinari-find-mailer
C-c ; f S	rinari-find-steps
C-c ; f Y	rinari-find-sass
C-c ; f a	rinari-find-application
C-c ; f c	rinari-find-controller
C-c ; f e	rinari-find-environment
C-c ; f f	rinari-find-file-in-project
C-c ; f h	rinari-find-helper
C-c ; f i	rinari-find-migration
C-c ; f j	rinari-find-javascript
C-c ; f l	rinari-find-lib
C-c ; f m	rinari-find-model
C-c ; f n	rinari-find-configuration
C-c ; f o	rinari-find-log
C-c ; f p	rinari-find-public
C-c ; f r	rinari-find-rspec
C-c ; f s	rinari-find-script
C-c ; f t	rinari-find-test
C-c ; f u	rinari-find-plugin
C-c ; f v	rinari-find-view
C-c ; f w	rinari-find-worker
C-c ; f x	rinari-find-fixture
C-c ; f y	rinari-find-stylesheet
C-c ; f z	rinari-find-rspec-fixture
```

### YASnippet html mode for Rails emacs key
```
1. %
  name: <%= %>
  key: %
2. %e
  name: <% @post.each do |post| %>
  key: %e
3. %t
  name: <%= f.label f.text_field %>
  key: %t   
4. %a
  name: <%= f.label f.text_area %>
  key: %a
5. %lk
  name: <%= link_to 'new post',new_post_path %>
  key: %lk
6. %err
  name: <%= if @post.errors.any? %>
  key: %err
7. %f
  name: <%= form_for %>
  key: %f
8. p%
  name: <p> <strong>Title:</strong></p>
  key: p%